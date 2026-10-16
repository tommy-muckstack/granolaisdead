import XCTest
@testable import GranolaIsDead

final class SpeechChunkerTests: XCTestCase {
    private func tone(_ seconds: Double, amp: Float = 0.2) -> [Float] {
        (0..<Int(seconds * 16000)).map { amp * sin(Float($0) * 2 * .pi * 220 / 16000) }
    }
    private func silence(_ seconds: Double) -> [Float] { [Float](repeating: 0, count: Int(seconds * 16000)) }

    func testSplitsOnPauseAndKeepsTimes() {
        var c = SpeechChunker()
        let chunks = c.feed(silence(1) + tone(2) + silence(1.2) + tone(1.5) + silence(1))
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].start, 0.5, accuracy: 0.11) // keeps 0.5 s lead-in
        XCTAssertEqual(chunks[1].start, 3.0, accuracy: 0.8)
    }

    func testDropsPureSilence() {
        var c = SpeechChunker()
        XCTAssertTrue(c.feed(silence(10)).isEmpty)
        XCTAssertNil(c.flush())
    }

    func testLongMonologueIsCutNearMax() {
        var c = SpeechChunker()
        // Speech-like: 0.4 s words with 0.15 s gaps, never a 0.7 s pause.
        var talk: [Float] = []
        while talk.count < 45 * 16000 { talk += tone(0.4) + silence(0.15) }
        let chunks = c.feed(talk)
        XCTAssertGreaterThanOrEqual(chunks.count, 2)
        XCTAssertTrue(chunks.allSatisfy { $0.end - $0.start <= 20.1 })
    }
}

final class EchoFilterTests: XCTestCase {
    func testMicRepeatingSystemAudioIsEcho() {
        let sys = TranscriptSegment(speaker: "Them", source: .system, start: 10, end: 14, text: "We should ship the pricing page on Friday")
        let mic = TranscriptSegment(speaker: "Me", source: .mic, start: 10.4, end: 14.2, text: "ship the pricing page on Friday")
        XCTAssertTrue(EchoFilter.isEcho(mic, of: [sys]))
        let own = TranscriptSegment(speaker: "Me", source: .mic, start: 15, end: 17, text: "Sounds good, I can draft the email")
        XCTAssertFalse(EchoFilter.isEcho(own, of: [sys]))
    }
}

@MainActor
final class NoteParsingTests: XCTestCase {
    func testParsesSectionsActionsAndOwnLines() {
        var note = Note()
        note.myNotes = "Pricing cap at three projects"
        let md = """
        Here are your notes:
        ### Decisions
        - - Pricing cap at three projects
          - Free tier stays
        ### Action items
        - [Sam] update pricing page by Friday
        - [x] Me: send recap
        """
        let e = NoteEngine.parse(md, note: note, engine: "test")
        XCTAssertEqual(e.sections.map(\.heading), ["Decisions", "Action items"])
        XCTAssertEqual(e.sections[0].lines[0].text, "Pricing cap at three projects")
        XCTAssertTrue(e.sections[0].lines[0].mine)
        XCTAssertEqual(e.sections[0].lines[1].level, 1)
        XCTAssertFalse(e.sections[0].lines[1].mine)
        XCTAssertEqual(e.sections[1].lines[0].text, "Sam: update pricing page by Friday")
        XCTAssertEqual(e.sections[1].lines[0].done, false)
        XCTAssertEqual(e.sections[1].lines[1].done, true)
    }

    func testBasicEnhancerFindsActionsAndDecisions() {
        var note = Note()
        note.transcript = [
            TranscriptSegment(speaker: "Them", source: .system, start: 0, end: 5, text: "We decided to keep the free tier but cap it at three projects."),
            TranscriptSegment(speaker: "Me", source: .mic, start: 5, end: 9, text: "I'll draft the announcement email and send it to the team by Thursday."),
        ]
        let e = BasicEnhancer.enhance(note, template: .auto)
        XCTAssertTrue(e.sections.contains { $0.heading == "Decisions" })
        let actions = e.sections.first { $0.heading == "Action items" }
        XCTAssertEqual(actions?.lines.first?.done, false)
        XCTAssertTrue(actions?.lines.first?.text.hasPrefix("Me: ") ?? false)
    }

    func testOwnLinesAreAlwaysKept() {
        var note = Note()
        note.myNotes = "free tier cap\n- soft launch monday"
        let e = NoteEngine.parse("### Decisions\n- Free tier limited to three projects\n### Launch\n- Rollout on Monday to 10%", note: note, engine: "t")
        let kept = NoteEngine.keepOwnLines(e, note: note)
        let mine = kept.sections.flatMap(\.lines).filter(\.mine).map(\.text)
        XCTAssertEqual(Set(mine), ["Free tier cap", "Soft launch monday"])
        XCTAssertEqual(kept.sections[0].lines[0].text, "Free tier cap")
    }

    func testWindowsNeverDropText() {
        let text = (0..<500).map { "line \($0) with some words" }.joined(separator: "\n")
        let w = Prompts.windows(text, size: 1000)
        XCTAssertEqual(w.joined(separator: "\n"), text)
        XCTAssertTrue(w.allSatisfy { $0.count <= 1000 })
    }
}
