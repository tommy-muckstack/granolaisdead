import Foundation

/// `GranolaIsDead --transcribe <16k mono wav> [--as mic|system]` runs a file
/// through the live pipeline (chunker → Parakeet → enhanced notes) and prints
/// the result. Used to verify transcription without granting mic access.
enum DebugCLI {
    @MainActor
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--transcribe"), i + 1 < args.count else { return false }
        let url = URL(fileURLWithPath: args[i + 1])
        let mic = args.contains("mic")
        Task { @MainActor in
            await Transcriber.shared.load { p in if Int(p * 100) % 10 == 0 { FileHandle.standardError.write("model \(Int(p * 100))%\n".data(using: .utf8)!) } }
            let samples = WavWriter.readSamples(from: url)
            var chunker = SpeechChunker()
            var chunks: [SpeechChunker.Chunk] = []
            for start in stride(from: 0, to: samples.count, by: 4000) {
                chunks += chunker.feed(Array(samples[start..<min(samples.count, start + 4000)]))
            }
            if let c = chunker.flush() { chunks.append(c) }
            var note = Note(title: "CLI test")
            for c in chunks {
                let text = await Transcriber.shared.transcribe(c.samples)
                guard MeetingRecorder.isSpeech(text) else { continue }
                note.transcript.append(TranscriptSegment(speaker: mic ? "Me" : "Them", source: mic ? .mic : .system, start: c.start, end: c.end, text: text))
                print(String(format: "[%6.1f–%6.1f] %@", c.start, c.end, text))
            }
            if args.contains("--save") { note.myNotes = "free tier cap\nsoft launch monday" }
            let e = await NoteEngine.enhance(note)
            print("\n--- enhanced (\(e.engine)) ---\n" + e.markdown)
            if args.contains("--save") {
                note.enhanced = e
                note.title = "Onboarding launch plan"
                note.myNotes = "free tier cap\nsoft launch monday"
                note.attendees = [Attendee(name: "Guest", email: "guest@example.com")]
                note.startedAt = Date().addingTimeInterval(-3600); note.endedAt = Date().addingTimeInterval(-1800)
                note.chat = []
                let saved = NoteStore.shared.create { $0 = note }
                NoteStore.shared.flushAll()
                print("saved \(saved.id)")
                try? await Task.sleep(for: .seconds(1))
            }
            exit(0)
        }
        return true
    }
}
