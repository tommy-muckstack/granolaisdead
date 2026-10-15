import { TEMPLATES, type Action, type Enhanced, type Line, type Note, type Section } from "./types";
const STOP = new Set("the of and to a in is it you that he was for on are with as i his they be at one have this from or had by not but what some we can out other were all there when up use your how said an each she which do their time if will way about many then them would like so these her make see him has more could go come did no most my over know than who may been now find just yeah okay ok um uh really think also get got going".split(" "));
const words = (s: string) => (s.toLowerCase().match(/[a-z][a-z'’-]*/g) ?? []).map(w => w.replace(/['’]s$/, ""));
const content = (s: string) => words(s).filter(w => w.length > 2 && !STOP.has(w));
const DAYS = "monday|tuesday|wednesday|thursday|friday|saturday|sunday";
const DUE = new RegExp(`\\b(?:by|before|on|next|this|until)\\s+(?:(?:${DAYS})|week|month|quarter|eod|end of (?:day|week|month|quarter)|tomorrow|today)\\b|\\b(?:tomorrow|tonight|asap|eod)\\b`, "i");
const ACTION = /\b(?:i'll|i will|we'll|we will|let's|lets|need to|needs to|have to|has to|should|going to|gonna|action item|todo|to-do|follow up|follow-up|can you|could you|will send|will share|will schedule|will draft|will review)\b/i;
const ACTION_VERB = /\b(?:send|schedule|share|review|draft|prepare|update|book|set up|write|create|email|call|check|fix|ship|deliver|finish|confirm|circulate|loop in|reach out|follow up|research|look into|investigate|add|build|test|fill|own|handle|lead|monitor|coordinate|organize|document)\b/i;
const ACTION_PHRASE = new RegExp(`(?:${ACTION.source})\\s+(?:[\\w'’-]+\\s+){0,2}(?:${ACTION_VERB.source})`, "i");
const DECISION = /\b(?:decided|agreed|we're going with|we are going with|let's go with|the plan is|settled on|approved|final decision|we'll go with|going ahead with|signed off)\b/i;
/** Split a transcript into {speaker, text} sentences. Lines like "Maya: ..." give a speaker; timestamps like [00:12] are dropped. */
export function parseTranscript(t: string): { speaker?: string; text: string }[] {
  const out: { speaker?: string; text: string }[] = [];
  for (const raw of t.split(/\n+/)) { let line = raw.replace(/^\s*\[?\d{1,2}:\d{2}(?::\d{2})?\]?\s*/, "").trim(); if (!line) continue; let speaker: string | undefined; const m = /^([A-Z][\w .'-]{0,24}):\s+(.*)$/.exec(line); if (m) { speaker = m[1]!.trim(); line = m[2]!; }
    for (const s of line.match(/[^.!?]+[.!?]+|[^.!?]+$/g) ?? []) { const text = s.trim(); if (text.split(/\s+/).length >= 3) out.push({ ...(speaker ? { speaker } : {}), text }); } }
  return out;
}
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
const clean = (s: string) => cap(s.replace(/^(?:so|and|but|well|okay|ok|yeah|um|uh|like|right)[, ]+/i, "").replace(/\s+/g, " ").replace(/[.!?]+$/, "").trim());
function ownerOf(s: { speaker?: string; text: string }): string | undefined {
  const t = s.text.replace(/^(?:yes|yeah|sure|okay|ok|great|right|well|so|and|then|also)[, ]+/i, "");
  if (/^(?:i'll|i will|i can|i need to|i should|let me)\b/i.test(t)) return s.speaker;
  const m = /^([A-Z][a-z]+)\s+(?:will|can|should|needs to|is going to|'ll)\b/.exec(t); if (m && !/^(?:We|They|You|It|This|That|There|He|She|Let)$/.test(m[1]!)) return m[1];
  const y = /^(?:can|could) you\b/i.test(s.text); void y; return undefined;
}
export function extractActions(sents: { speaker?: string; text: string }[]): Action[] {
  const out: Action[] = []; const seen = new Set<string>();
  for (const s of sents) { const n = s.text.split(/\s+/).length; if (n < 4 || n > 32 || /\?\s*$/.test(s.text)) continue; if (!ACTION_PHRASE.test(s.text)) continue; if (/^(?:i think|i guess|maybe|if)\b/i.test(s.text)) continue;
    const key = content(s.text).slice(0, 5).join(" "); if (seen.has(key)) continue; seen.add(key); const a: Action = { text: clean(s.text) }; const o = ownerOf(s); if (o) a.owner = o; const d = DUE.exec(s.text); if (d) a.due = d[0].toLowerCase(); out.push(a); }
  return out.slice(0, 12);
}
export function extractDecisions(sents: { text: string }[]) { const out: string[] = []; for (const s of sents) if (DECISION.test(s.text) && !/\?\s*$/.test(s.text)) out.push(clean(s.text)); return [...new Set(out)].slice(0, 8); }
export function extractQuestions(sents: { text: string }[]) { return sents.filter(s => /\?\s*$/.test(s.text) && s.text.split(/\s+/).length >= 3).map(s => clean(s.text) + "?").slice(0, 6); }
/** Extractive key points: sentences scored by the frequency of their content words (and numbers), returned in original order. */
export function keyPoints(sents: { text: string }[], max: number, exclude: Set<string> = new Set()): string[] {
  const freq = new Map<string, number>(); for (const s of sents) for (const w of new Set(content(s.text))) freq.set(w, (freq.get(w) ?? 0) + 1);
  const scored = sents.map((s, i) => { const cw = content(s.text); const n = s.text.split(/\s+/).length; if (n < 6 || n > 40 || /\?\s*$/.test(s.text) || exclude.has(s.text)) return { i, score: -1, text: s.text }; const raw = cw.reduce((a, w) => a + ((freq.get(w) ?? 1) - 0.5), 0) / Math.sqrt(cw.length || 1); const bonus = /\d/.test(s.text) ? 1.5 : 0; return { i, score: raw + bonus, text: s.text }; });
  const top = scored.filter(s => s.score > 0).sort((a, b) => b.score - a.score).slice(0, max).sort((a, b) => a.i - b.i); return top.map(t => clean(t.text));
}
const overlap = (a: string, b: string) => { const A = new Set(content(a)); return content(b).filter(w => A.has(w)).length; };
function pickSection(text: string, sections: { heading: string; keys: string[] }[]): number {
  if (sections.length === 1) return 0; const w = text.toLowerCase(); let best = -1, bi = sections.length - 1;
  sections.forEach((s, i) => { const sc = s.keys.filter(k => w.includes(k)).length; if (sc > best) { best = sc; bi = i; } }); return best <= 0 ? 0 : bi;
}
export function enhance(n: Pick<Note, "title" | "template" | "notes" | "transcript">, now = Date.now()): Enhanced {
  const tpl = TEMPLATES.find(t => t.id === n.template) ?? TEMPLATES[0]!; const sents = parseTranscript(n.transcript);
  const actions = extractActions(sents); const decisions = extractDecisions(sents); const questions = extractQuestions(sents);
  const taken = new Set([...sents.filter(s => actions.some(a => clean(s.text) === a.text) || decisions.includes(clean(s.text))).map(s => s.text)]);
  const sections: Section[] = tpl.sections.map(s => ({ heading: s.heading, lines: [] }));
  const myLines = n.notes.split(/\n+/).map(l => l.replace(/^[\s*•·\-–]+/, "").trim()).filter(Boolean); const usedDetail = new Set<string>();
  for (const l of myLines) { const best = sents.filter(s => !taken.has(s.text) && !usedDetail.has(s.text)).map(s => ({ s, o: overlap(l, s.text) })).sort((a, b) => b.o - a.o)[0];
    const line: Line = { text: cap(l), mine: true }; if (best && best.o >= 2 && clean(best.s.text).toLowerCase() !== l.toLowerCase()) { line.detail = clean(best.s.text) + "."; usedDetail.add(best.s.text); } sections[pickSection(l, tpl.sections)]!.lines.push(line); }
  const wordCount = sents.reduce((a, s) => a + s.text.split(/\s+/).length, 0); const nKey = Math.max(0, Math.min(10, Math.round(sents.length / 5))); const covered = new Set([...taken, ...usedDetail]);
  const kp = keyPoints(sents, nKey, covered); for (const k of kp) sections[pickSection(k, tpl.sections)]!.lines.push({ text: k + ".", mine: false });
  const summary = wordCount < 25 ? [] : keyPoints(sents, 3, taken).slice(0, 3).map(s => s + ".");
  return { summary, sections: sections.filter(s => s.lines.length), actions, decisions, questions, generatedAt: now };
}
export function toMarkdown(n: Pick<Note, "title">, e: Enhanced): string {
  const L: string[] = [`# ${n.title || "Untitled meeting"}`, ""];
  if (e.summary.length) L.push("## Summary", ...e.summary.map(s => `- ${s}`), "");
  for (const s of e.sections) { L.push(`## ${s.heading}`); for (const l of s.lines) { L.push(`- ${l.text}`); if (l.detail) L.push(`  - ${l.detail}`); } L.push(""); }
  if (e.decisions.length) L.push("## Decisions", ...e.decisions.map(d => `- ${d}`), "");
  if (e.actions.length) L.push("## Action items", ...e.actions.map(a => `- [ ] ${a.text}${a.owner ? ` (${a.owner})` : ""}${a.due ? ` — ${a.due}` : ""}`), "");
  if (e.questions.length) L.push("## Open questions", ...e.questions.map(q => `- ${q}`), "");
  return L.join("\n").trim() + "\n";
}
/** Local "ask your notes": returns the best-matching sentences from notes + transcript for a question. */
export function ask(question: string, n: Pick<Note, "notes" | "transcript">): { answer: string; sources: string[] } {
  const q = new Set(content(question)); if (!q.size) return { answer: "Ask about something specific, like a person, number or decision.", sources: [] };
  const pool = [...n.notes.split(/\n+/).map(t => ({ t: t.replace(/^[\s*•·\-–]+/, "").trim(), w: 1.3 })), ...parseTranscript(n.transcript).map(s => ({ t: s.speaker ? `${s.speaker}: ${s.text}` : s.text, w: 1 }))].filter(p => p.t.length > 8);
  const scored = pool.map(p => ({ ...p, s: content(p.t).filter(w => q.has(w)).length * p.w })).filter(p => p.s > 0).sort((a, b) => b.s - a.s).slice(0, 3);
  if (!scored.length) return { answer: "I couldn't find that in this meeting's notes or transcript.", sources: [] };
  return { answer: scored.map(s => s.t).join("\n"), sources: scored.map(s => s.t) };
}
export const SAMPLE_TRANSCRIPT = `Maya: Thanks for joining everyone. Today we need to settle the launch plan for the new onboarding flow and talk about the pricing page.
Sam: Sure. The onboarding flow is basically done, we finished the last two screens yesterday and the signup conversion in the test cohort went up to 34 percent from 21 percent.
Maya: That's a big jump. What was the main driver behind the conversion improvement?
Sam: Mostly removing the credit card step and adding the progress bar. Customers told us the card step felt like a trap, so removing it made the flow feel much more trustworthy.
Priya: On pricing, I'm worried that the free tier is too generous. Support tickets from free users already doubled since March and the support queue is slow.
Maya: Fair point. We decided to keep the free tier but cap it at three projects, and we agreed the new limit ships with the launch.
Priya: I'll draft the announcement email and send it to the team by Thursday.
Sam: I'll update the pricing page copy before Friday and set up the redirect for the old plans page.
Maya: Great. We also need to schedule a review with legal about the new terms next week. Can you book that, Priya?
Priya: Yes, I will book the legal review for Tuesday.
Sam: One risk is the database migration. It is blocked until the platform team finishes the index rebuild, which could delay the launch by a few days.
Maya: Okay. Let's go with a soft launch to ten percent of users on Monday and expand if the error rate stays under one percent. Who owns monitoring?
Sam: I'll own monitoring and share a dashboard with everyone by Monday morning.`;
