import AppKit
import Combine
import Foundation

/// Speech model state, shown in onboarding, the recording bar and Settings.
@MainActor
final class SpeechModel: ObservableObject {
    static let shared = SpeechModel()
    enum State: Equatable { case idle, downloading(Double), ready, failed }
    @Published private(set) var state: State = .idle

    func prepare() {
        guard state == .idle || state == .failed else { return }
        state = .downloading(0)
        Task {
            await Transcriber.shared.load { p in Task { @MainActor in
                if case .downloading = SpeechModel.shared.state { SpeechModel.shared.state = .downloading(p) }
            } }
            state = await Transcriber.shared.isReady ? .ready : .failed
            if state == .failed { Analytics.track("app_model_failed") }
        }
    }
}

/// One shared model load; chunks recorded while the model is still
/// downloading wait for it instead of being dropped. (Parakeet's AsrManager is
/// itself an actor, so interleaved chunks are safe.)
actor Transcriber {
    static let shared = Transcriber()
    private let service = TranscriptionService.shared
    private var loading: Task<Void, Never>?
    var isReady: Bool { service.isReady }

    func load(progress: @escaping @Sendable (Double) -> Void) async {
        if service.isReady { return }
        if let loading { await loading.value; return }
        let svc = service
        let t = Task { await svc.load(kind: .parakeet, progress: progress) }
        loading = t
        await t.value
        loading = nil
    }

    func transcribe(_ samples: [Float]) async -> String {
        if !service.isReady {
            if let loading { await loading.value } else { await load { _ in } }
        }
        guard service.isReady else { return "" }
        return await service.transcribe(samples)
    }
}

/// Records one meeting: microphone ("Me") and computer audio ("Them", via a
/// CoreAudio process tap, so no bot ever joins the call), streams both
/// through the chunker into a live transcript, and keeps WAVs on disk.
@MainActor
final class MeetingRecorder: ObservableObject {
    static let shared = MeetingRecorder()

    @Published private(set) var noteID: UUID?
    @Published private(set) var isPaused = false
    @Published private(set) var micLevel: Float = 0
    @Published private(set) var systemLevel: Float = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var systemAudioAvailable = true
    /// Notes whose final transcription chunks are still in flight.
    @Published private(set) var finishing: Set<UUID> = []

    var isRecording: Bool { noteID != nil }
    /// The note a start is in progress for (permission prompt, device spin-up).
    @Published private(set) var startingNoteID: UUID?
    var isBusy: Bool { isRecording || startingNoteID != nil }

    private var micSession: UUID?
    private var tap: SystemAudioTap?
    private var micWriter: WavWriter?
    private var sysWriter: WavWriter?
    private var micChunker = SpeechChunker()
    private var sysChunker = SpeechChunker()
    private let sysBuffer = SampleBuffer()
    private var timer: Timer?
    private var startedClock = Date()
    private var pausedTotal: TimeInterval = 0
    private var pausedAt: Date?
    private var inFlight: [UUID: Int] = [:]
    private var onFinished: [UUID: () -> Void] = [:]
    private var cancelStart = false

    // MARK: Start / stop

    func start(noteID id: UUID) async {
        guard !isBusy else { return }
        startingNoteID = id; cancelStart = false
        defer { startingNoteID = nil }
        guard await Permissions.requestMicrophone() else {
            Toast.show("GranolaIsDead needs the microphone to transcribe. Turn it on in System Settings.", systemImage: "mic.slash")
            Permissions.openPrivacy(.microphone)
            return
        }
        SpeechModel.shared.prepare()
        // Resuming right after Stop: let the previous session's last chunks
        // land first, so its notes callback can't fire mid-recording and the
        // new lines start after the old ones.
        var waited = 0
        while finishing.contains(id), waited < 480, !cancelStart { try? await Task.sleep(for: .milliseconds(250)); waited += 1 }
        finishing.remove(id); onFinished[id] = nil
        let store = NoteStore.shared
        guard !cancelStart, store.note(id) != nil else { return }
        let offset = store.note(id)?.transcript.map(\.end).max() ?? 0 // resuming appends after existing lines
        micChunker = SpeechChunker(); sysChunker = SpeechChunker()
        timeOffset = offset
        let session: UUID
        do {
            session = try await AudioCapture.shared.begin(.raw)
        } catch {
            Toast.show("Couldn’t start the microphone.", systemImage: "mic.slash")
            return
        }
        // Stopped or deleted while the mic was spinning up.
        guard !cancelStart, store.note(id) != nil else { _ = AudioCapture.shared.end(session); return }
        micSession = session
        micWriter = WavWriter(url: Recordings.nextURL(id, track: "mic"))
        sysWriter = WavWriter(url: Recordings.nextURL(id, track: "system"))
        let t = SystemAudioTap()
        let buffer = sysBuffer
        buffer.reset()
        t.onSamples = { buffer.append($0) }
        do { try t.start(); tap = t; systemAudioAvailable = true }
        catch { systemAudioAvailable = false; NSLog("GranolaIsDead [Tap] start failed: \(error)") }

        noteID = id; isPaused = false; elapsed = 0; pausedTotal = 0; pausedAt = nil; startedClock = Date()
        store.update(id, immediately: true) { n in
            if n.startedAt == nil { n.startedAt = Date() }
            n.endedAt = nil
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RecordingIndicator.shared.show()
        Analytics.track("app_meeting_started", ["system_audio": systemAudioAvailable])
    }

    private var timeOffset: Double = 0

    func togglePause() {
        guard isRecording else { return }
        if isPaused { if let p = pausedAt { pausedTotal += Date().timeIntervalSince(p) }; pausedAt = nil }
        else { pausedAt = Date() }
        isPaused.toggle()
        Analytics.track(isPaused ? "app_meeting_paused" : "app_meeting_resumed")
    }

    /// Stop capturing. Final chunks keep transcribing; `then` runs once the
    /// transcript is complete (enhanced notes are generated there).
    func stop(then: (() -> Void)? = nil) {
        guard let id = noteID else {
            if startingNoteID != nil { cancelStart = true }
            return
        }
        tick()
        timer?.invalidate(); timer = nil
        if let micSession {
            let native = AudioCapture.shared.drainNative(micSession)
            if !isPaused { ingest(AudioCapture.resample(native.samples, from: native.sampleRate, to: 16000), mic: true) }
            _ = AudioCapture.shared.end(micSession)
        }
        micSession = nil
        tap?.stop(); tap = nil
        if !isPaused { ingest(sysBuffer.take(), mic: false) }
        if let c = micChunker.flush() { transcribe(c, mic: true, note: id) }
        if let c = sysChunker.flush() { transcribe(c, mic: false, note: id) }
        _ = micWriter?.close(); _ = sysWriter?.close(); micWriter = nil; sysWriter = nil
        NoteStore.shared.update(id, immediately: true) { $0.endedAt = Date() }
        Analytics.track("app_meeting_stopped", ["duration_bucket": Self.bucket(elapsed)])
        noteID = nil; isPaused = false; micLevel = 0; systemLevel = 0
        RecordingIndicator.shared.hide()
        if let then { onFinished[id] = then }
        finishing.insert(id)
        checkFinished(id)
    }

    // MARK: Pump

    private func tick() {
        guard noteID != nil else { return }
        elapsed = Date().timeIntervalSince(startedClock) - pausedTotal - (pausedAt.map { Date().timeIntervalSince($0) } ?? 0)
        var mic: [Float] = []
        if let micSession {
            let native = AudioCapture.shared.drainNative(micSession)
            mic = AudioCapture.resample(native.samples, from: native.sampleRate, to: 16000)
        }
        let sys = sysBuffer.take()
        micLevel = Self.level(mic); systemLevel = Self.level(sys)
        guard !isPaused else { micLevel = 0; systemLevel = 0; return }
        ingest(mic, mic: true)
        ingest(sys, mic: false)
    }

    private func ingest(_ samples: [Float], mic: Bool) {
        guard !samples.isEmpty, let id = noteID else { return }
        if mic {
            micWriter?.append(samples)
            for c in micChunker.feed(samples) { transcribe(c, mic: true, note: id) }
        } else {
            sysWriter?.append(samples)
            for c in sysChunker.feed(samples) { transcribe(c, mic: false, note: id) }
        }
    }

    private func transcribe(_ chunk: SpeechChunker.Chunk, mic: Bool, note id: UUID) {
        inFlight[id, default: 0] += 1
        let offset = timeOffset
        Task {
            let text = await Transcriber.shared.transcribe(chunk.samples)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                self.inFlight[id, default: 1] -= 1
                defer { self.checkFinished(id) }
                guard Self.isSpeech(text) else { return }
                let seg = TranscriptSegment(speaker: mic ? "Me" : "Them", source: mic ? .mic : .system,
                                            start: chunk.start + offset, end: chunk.end + offset, text: text)
                NoteStore.shared.update(id) { n in
                    if mic {
                        if EchoFilter.isEcho(seg, of: n.transcript.filter { $0.source == .system }) { return }
                    } else {
                        n.transcript.removeAll { $0.source == .mic && EchoFilter.isEcho($0, of: [seg]) }
                    }
                    let i = n.transcript.firstIndex { $0.start > seg.start } ?? n.transcript.count
                    n.transcript.insert(seg, at: i)
                }
            }
        }
    }

    private func checkFinished(_ id: UUID) {
        guard finishing.contains(id), (inFlight[id] ?? 0) == 0 else { return }
        inFlight[id] = nil
        finishing.remove(id)
        NoteStore.shared.flushAll()
        onFinished.removeValue(forKey: id)?()
    }

    // MARK: Helpers

    static func isSpeech(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard letters >= 2 else { return false }
        let lower = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return !["you", "thank you", "thanks for watching", "bye", "uh", "um", "mm", "hmm"].contains(lower)
            || text.split(separator: " ").count > 2
    }

    private static func level(_ s: [Float]) -> Float {
        guard !s.isEmpty else { return 0 }
        let tail = s.suffix(1600)
        let rms = sqrt(tail.reduce(Float(0)) { $0 + $1 * $1 } / Float(tail.count))
        return min(1, rms * 8)
    }

    static func bucket(_ t: TimeInterval) -> String {
        switch t { case ..<60: return "lt_1m"; case ..<900: return "1_15m"; case ..<2700: return "15_45m"; default: return "gt_45m" }
    }
}

/// Lock-protected sample accumulator for the tap's processing queue.
final class SampleBuffer: @unchecked Sendable {
    private var samples: [Float] = []
    private let lock = NSLock()
    func append(_ s: [Float]) { lock.lock(); samples.append(contentsOf: s); lock.unlock() }
    func take() -> [Float] { lock.lock(); defer { samples = []; lock.unlock() }; return samples }
    func reset() { lock.lock(); samples = []; lock.unlock() }
}
