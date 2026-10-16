import Foundation

/// Cuts one 16 kHz mono track into utterance-sized chunks for live ASR.
///
/// Energy-gated in 0.1 s frames against an adaptive noise floor (a quiet mic
/// and a loud call side both work). A chunk closes after 0.7 s of silence once
/// it holds speech, or at the quietest frame near 20 s so a monologue still
/// streams. Pure silence is dropped without ever reaching the model.
struct SpeechChunker {
    struct Chunk { let samples: [Float]; let start: Double; let end: Double }

    static let rate = 16000
    static let frame = rate / 10

    private(set) var consumed = 0 // samples fed so far (track clock)
    private var pending: [Float] = []
    private var pendingStart = 0
    private var frameLevels: [Float] = []
    private var floor: Float = 0.002
    private var speechFrames = 0
    private var trailingSilent = 0

    var minChunk = 1.2, silenceToClose = 0.7, maxChunk = 20.0

    mutating func feed(_ samples: [Float]) -> [Chunk] {
        var out: [Chunk] = []
        var i = 0
        while i < samples.count {
            // Fill the current frame.
            let need = Self.frame - (pending.count % Self.frame)
            let take = min(need, samples.count - i)
            pending.append(contentsOf: samples[i..<(i + take)])
            i += take
            consumed += take
            guard pending.count % Self.frame == 0 else { continue }
            let f = pending.suffix(Self.frame)
            let rms = sqrt(f.reduce(Float(0)) { $0 + $1 * $1 } / Float(Self.frame))
            frameLevels.append(rms)
            // Floor follows quiet frames quickly, loud frames slowly.
            floor = rms < floor ? floor * 0.7 + rms * 0.3 : floor * 0.995 + rms * 0.005
            let speaking = rms > max(0.006, floor * 3)
            if speaking { speechFrames += 1; trailingSilent = 0 } else { trailingSilent += 1 }
            if let c = maybeClose() { out.append(c) }
        }
        return out
    }

    /// Whatever is left when the meeting stops.
    mutating func flush() -> Chunk? {
        defer { reset(at: consumed) }
        guard speechFrames >= 3, !pending.isEmpty else { return nil }
        return Chunk(samples: pending, start: seconds(pendingStart), end: seconds(pendingStart + pending.count))
    }

    private mutating func maybeClose() -> Chunk? {
        let dur = Double(pending.count) / Double(Self.rate)
        let silentDur = Double(trailingSilent) / 10
        if speechFrames == 0 {
            // Keep at most 0.5 s of lead-in silence so word onsets survive.
            let keep = Self.frame * 5
            if pending.count > keep {
                let drop = pending.count - keep
                pending.removeFirst(drop); frameLevels.removeFirst(min(drop / Self.frame, frameLevels.count))
                pendingStart += drop
            }
            return nil
        }
        if dur >= minChunk, silentDur >= silenceToClose, speechFrames >= 3 {
            return cut(at: pending.count)
        }
        if dur >= maxChunk {
            // Quietest frame in the last 4 s — never split mid-word if avoidable.
            let window = min(40, frameLevels.count)
            let base = frameLevels.count - window
            var best = frameLevels.count - 1, bestLevel = Float.greatestFiniteMagnitude
            for k in base..<frameLevels.count where frameLevels[k] < bestLevel { bestLevel = frameLevels[k]; best = k }
            return cut(at: (best + 1) * Self.frame)
        }
        if speechFrames < 3, silentDur > 2 { // a click or a cough: discard
            reset(at: consumed)
        }
        return nil
    }

    private mutating func cut(at n: Int) -> Chunk {
        let samples = Array(pending.prefix(n))
        let chunk = Chunk(samples: samples, start: seconds(pendingStart), end: seconds(pendingStart + n))
        let rest = Array(pending.dropFirst(n))
        let restStart = pendingStart + n
        reset(at: restStart)
        pending = rest
        frameLevels = []
        // Re-scan the remainder's frames so its speech is not lost.
        var idx = 0
        while idx + Self.frame <= rest.count {
            let f = rest[idx..<(idx + Self.frame)]
            let rms = sqrt(f.reduce(Float(0)) { $0 + $1 * $1 } / Float(Self.frame))
            frameLevels.append(rms)
            if rms > max(0.006, floor * 3) { speechFrames += 1; trailingSilent = 0 } else { trailingSilent += 1 }
            idx += Self.frame
        }
        return chunk
    }

    private mutating func reset(at start: Int) {
        pending = []; frameLevels = []; pendingStart = start; speechFrames = 0; trailingSilent = 0
    }

    private func seconds(_ samples: Int) -> Double { Double(samples) / Double(Self.rate) }
}

/// Speakers on laptop speakers leak the far side into the mic. A mic line
/// that mostly repeats what computer audio said in the same few seconds is
/// that echo, not the user — drop it.
enum EchoFilter {
    static func words(_ s: String) -> [String] {
        s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 2 }
    }

    static func isEcho(_ mic: TranscriptSegment, of system: [TranscriptSegment]) -> Bool {
        let w = Set(words(mic.text))
        guard w.count >= 2 else { return false }
        let lo = mic.start - 4, hi = mic.end + 4
        let nearby = system.filter { seg in seg.end >= lo && seg.start <= hi }
        guard !nearby.isEmpty else { return false }
        var sys = Set<String>()
        for seg in nearby { sys.formUnion(words(seg.text)) }
        let shared = w.intersection(sys).count
        return Double(shared) / Double(w.count) >= 0.6
    }
}
