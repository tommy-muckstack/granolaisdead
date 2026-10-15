import { describe, it, expect } from "vitest";
import { parseTranscript, extractActions, extractDecisions, extractQuestions, keyPoints, enhance, toMarkdown, ask, SAMPLE_TRANSCRIPT } from "@/lib/notes/enhance";
const sents = parseTranscript(SAMPLE_TRANSCRIPT);
describe("transcript parsing", () => {
  it("splits speakers and sentences, drops timestamps and fragments", () => {
    const s = parseTranscript("[00:12] Maya: Hello there team. Ok.\n\nSam: We ship Friday!"); expect(s).toEqual([{ speaker: "Maya", text: "Hello there team." }, { speaker: "Sam", text: "We ship Friday!" }]);
    expect(parseTranscript("no speaker label here, just words. And more words follow.").every(x => x.speaker === undefined)).toBe(true);
  });
});
describe("extraction", () => {
  it("finds action items with owners and due dates", () => {
    const a = extractActions(sents); const by = (t: string) => a.find(x => x.text.includes(t))!;
    expect(by("draft the announcement email")).toMatchObject({ owner: "Priya", due: "by thursday" }); expect(by("update the pricing page copy")).toMatchObject({ owner: "Sam", due: "before friday" }); expect(by("book the legal review").owner).toBe("Priya"); expect(by("own monitoring").owner).toBe("Sam");
    expect(a.every(x => !x.text.endsWith("?"))).toBe(true);
  });
  it("finds decisions and open questions", () => {
    const d = extractDecisions(sents); expect(d.some(x => /cap it at three projects/.test(x))).toBe(true); expect(d.some(x => /soft launch/.test(x))).toBe(true);
    const q = extractQuestions(sents); expect(q.some(x => /main driver/.test(x))).toBe(true); expect(q.some(x => /Who owns monitoring/.test(x))).toBe(true);
  });
  it("key points prefer informative sentences and keep order", () => { const k = keyPoints(sents, 4); expect(k).toHaveLength(4); expect(k.every(x => !x.endsWith("?"))).toBe(true); expect(k.join(" ")).toMatch(/conversion|credit card|free tier|migration/i); });
  it("ignores hedged or too-short action-like sentences", () => { expect(extractActions(parseTranscript("Maybe we should send it. I think we should review it later. We will."))).toEqual([]); });
});
describe("enhance", () => {
  const e = enhance({ title: "Launch sync", template: "general", notes: "- signup conversion up to 34%\n- free tier cap\n- legal review", transcript: SAMPLE_TRANSCRIPT }, 1);
  it("keeps the user's own lines and attaches transcript detail", () => {
    const lines = e.sections.flatMap(s => s.lines); expect(lines.filter(l => l.mine).map(l => l.text)).toEqual(["Signup conversion up to 34%", "Free tier cap", "Legal review"]);
    expect(lines.find(l => l.text.startsWith("Signup"))!.detail).toMatch(/34 percent/); expect(lines.some(l => !l.mine)).toBe(true);
  });
  it("produces summary, actions, decisions, questions", () => { expect(e.summary.length).toBeGreaterThan(0); expect(e.actions.length).toBeGreaterThanOrEqual(4); expect(e.decisions.length).toBeGreaterThanOrEqual(2); expect(e.questions.length).toBeGreaterThanOrEqual(2); });
  it("routes lines into template sections", () => {
    const s = enhance({ title: "x", template: "standup", notes: "Fixed the login bug yesterday\nBlocked on the index rebuild", transcript: "" });
    expect(s.sections.map(x => x.heading)).toEqual(["Yesterday", "Blockers"]);
  });
  it("renders markdown", () => { const md = toMarkdown({ title: "Launch sync" }, e); expect(md).toMatch(/^# Launch sync/); expect(md).toMatch(/## Action items\n- \[ \] .*\(Priya\) — by thursday/); expect(md).toMatch(/## Decisions/); });
  it("works with notes only or transcript only", () => { expect(enhance({ title: "", template: "general", notes: "one idea", transcript: "" }).sections[0]!.lines).toEqual([{ text: "One idea", mine: true }]); expect(enhance({ title: "", template: "general", notes: "", transcript: SAMPLE_TRANSCRIPT }).sections.length).toBeGreaterThan(0); });
});
describe("ask", () => {
  it("retrieves matching lines with speakers, or admits it can't", () => {
    expect(ask("Who is booking the legal review?", { notes: "", transcript: SAMPLE_TRANSCRIPT }).answer).toMatch(/Priya: Yes, I will book the legal review/);
    expect(ask("What happened to conversion?", { notes: "", transcript: SAMPLE_TRANSCRIPT }).sources[0]).toMatch(/conversion/);
    expect(ask("quantum entanglement budget", { notes: "", transcript: SAMPLE_TRANSCRIPT }).sources).toEqual([]); expect(ask("the and of", { notes: "", transcript: "" }).sources).toEqual([]);
  });
});
