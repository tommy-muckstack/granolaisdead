"use client";
import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useLocal } from "@/lib/useLocal";
import { TEMPLATES, type Note, type Template } from "@/lib/notes/types";
import { ask, enhance, SAMPLE_TRANSCRIPT, toMarkdown } from "@/lib/notes/enhance";
const uid = () => "n" + Math.random().toString(36).slice(2, 10);
const blank = (): Note => ({ id: uid(), title: "", template: "general", notes: "", transcript: "", createdAt: Date.now(), updatedAt: Date.now() });
const groupOf = (t: number) => { const d = new Date(); d.setHours(0, 0, 0, 0); const day = 86400000; return t >= +d ? "Today" : t >= +d - day ? "Yesterday" : t >= +d - 6 * day ? "Previous 7 days" : "Earlier"; };
const SAMPLE_NOTES = "- onboarding flow done, conversion up\n- free tier worries\n- legal review\n- launch plan";
export function Workspace({ userId, noteId }: { userId: string; noteId?: string }) {
  const [notes, setNotes, ready] = useLocal<Note[]>(userId, "notes", []); const router = useRouter();
  const note = notes.find(n => n.id === noteId);
  const create = (init?: Partial<Note>) => { const n = { ...blank(), ...init }; setNotes(x => [n, ...x]); setTimeout(() => router.push(`/app/notes/${n.id}`), 60); };
  const sorted = useMemo(() => [...notes].sort((a, b) => b.updatedAt - a.updatedAt), [notes]);
  const groups = useMemo(() => { const g = new Map<string, Note[]>(); for (const n of sorted) { const k = groupOf(n.updatedAt); g.set(k, [...(g.get(k) ?? []), n]); } return [...g]; }, [sorted]);
  return <div className="gn"><aside className="gn__side"><button className="ids-btn ids-btn--primary" style={{ width: "100%" }} onClick={() => create()}>+ New note</button>
    <nav aria-label="Notes" data-testid="list">{groups.map(([g, list]) => <div key={g}><h4>{g}</h4>{list.map(n => <Link key={n.id} href={`/app/notes/${n.id}`} className={"gn__item" + (n.id === noteId ? " on" : "")}>{n.title || "Untitled meeting"}<span>{new Date(n.updatedAt).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}</span></Link>)}</div>)}</nav>
    {ready && !notes.length && <p className="ids-muted" style={{ fontSize: 13 }}>Your meeting notes will show up here.</p>}</aside>
    <main className="gn__main">{!ready ? <p className="ids-muted">Loading…</p> : noteId ? (note ? <NoteEditor key={note.id} note={note} onChange={p => setNotes(x => x.map(n => (n.id === note.id ? { ...n, ...p, updatedAt: Date.now() } : n)))} onDelete={() => { setNotes(x => x.filter(n => n.id !== note.id)); router.push("/app"); }} /> : <div className="ids-card" style={{ padding: 32 }}><h2>Note not found</h2><Link href="/app">Back to notes</Link></div>)
      : <div className="gn__empty" data-testid="empty"><h1 className="ids-h1" style={{ fontSize: 40 }}>Good meetings, good notes.</h1><p className="ids-muted" style={{ maxWidth: 520 }}>Jot down what matters during the call. We’ll weave in what was said: a summary, decisions and action items, with your own words kept front and center.</p>
        <div className="tb" style={{ justifyContent: "center" }}><button className="ids-btn ids-btn--primary" onClick={() => create()}>New note</button><button className="ids-btn ids-btn--secondary" onClick={() => create({ title: "Launch sync", template: "general", notes: SAMPLE_NOTES, transcript: SAMPLE_TRANSCRIPT })}>Try a sample meeting</button></div></div>}</main></div>;
}
type Tab = "notes" | "enhanced" | "transcript";
function NoteEditor({ note, onChange, onDelete }: { note: Note; onChange: (p: Partial<Note>) => void; onDelete: () => void }) {
  const [tab, setTab] = useState<Tab>(note.enhanced ? "enhanced" : "notes"); const [q, setQ] = useState(""); const [chat, setChat] = useState<{ q: string; a: string }[]>([]); const [rec, setRec] = useState(false); const [interim, setInterim] = useState(""); const [copied, setCopied] = useState(false);
  const recRef = useRef<any>(null); const SR = typeof window !== "undefined" ? (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition : null;
  const transcriptRef = useRef(note.transcript); transcriptRef.current = note.transcript;
  useEffect(() => () => recRef.current?.stop?.(), []);
  const doEnhance = () => { onChange({ enhanced: enhance(note), done: [] }); setTab("enhanced"); };
  const startRec = () => { if (!SR) return; const r = new SR(); r.continuous = true; r.interimResults = true; r.lang = "en-US";
    r.onresult = (e: any) => { let fin = "", tmp = ""; for (let i = e.resultIndex; i < e.results.length; i++) { const t = e.results[i][0].transcript; if (e.results[i].isFinal) fin += t.trim() + " "; else tmp += t; } if (fin) onChange({ transcript: (transcriptRef.current ? transcriptRef.current.replace(/\s*$/, "\n") : "") + fin.trim() }); setInterim(tmp); };
    r.onend = () => { setRec(false); setInterim(""); }; r.start(); recRef.current = r; setRec(true); setTab("transcript"); };
  const stopRec = () => { recRef.current?.stop(); setRec(false); };
  const md = note.enhanced ? toMarkdown(note, note.enhanced) : "";
  const e = note.enhanced; const done = new Set(note.done ?? []);
  const submit = (ev: React.FormEvent) => { ev.preventDefault(); if (!q.trim()) return; const r = ask(q, note); setChat(c => [{ q, a: r.answer }, ...c]); setQ(""); };
  return <div className="gn__note"><div className="gn__head"><input className="gn__title" aria-label="Note title" placeholder="New meeting" value={note.title} onChange={ev => onChange({ title: ev.target.value })} />
    <div className="tb"><select aria-label="Template" value={note.template} onChange={ev => onChange({ template: ev.target.value as Template })}>{TEMPLATES.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}</select>
      <button className="iconbtn" onClick={() => { if (confirm("Delete this note?")) onDelete(); }}>Delete</button></div></div>
    <div className="gn__tabs" role="tablist">{(["notes", "enhanced", "transcript"] as Tab[]).map(t => <button key={t} role="tab" aria-selected={tab === t} className={tab === t ? "on" : ""} onClick={() => setTab(t)}>{t === "notes" ? "My notes" : t === "enhanced" ? "Enhanced" : "Transcript"}</button>)}</div>
    <div className="gn__pane">
      {tab === "notes" && <textarea className="gn__ta" aria-label="My notes" placeholder={"Write notes as the meeting happens…\n- key numbers\n- names\n- things you want to remember"} value={note.notes} onChange={ev => onChange({ notes: ev.target.value })} />}
      {tab === "transcript" && <div><div className="gn__rec"><button className={"ids-btn " + (rec ? "ids-btn--secondary" : "ids-btn--primary")} onClick={rec ? stopRec : startRec} disabled={!SR} title={SR ? "" : "Speech recognition isn't available in this browser"}>{rec ? "● Stop recording" : "Start recording"}</button>
        <button className="ids-btn ids-btn--secondary" onClick={() => onChange({ transcript: SAMPLE_TRANSCRIPT })}>Load sample transcript</button>
        <span className="ids-muted" style={{ fontSize: 13 }}>{SR ? "Uses your browser’s speech recognition (Chrome sends audio to Google). Nothing is stored by us." : "This browser has no speech recognition. Paste a transcript below."}</span></div>
        <textarea className="gn__ta" aria-label="Transcript" placeholder={"Paste a transcript. Lines like “Maya: …” give each speaker a name."} value={note.transcript} onChange={ev => onChange({ transcript: ev.target.value })} />{interim && <p className="ids-muted" aria-live="polite">{interim}…</p>}</div>}
      {tab === "enhanced" && (!e ? <div className="gn__empty2" data-testid="noenh"><p className="ids-muted">Add your notes and a transcript, then enhance them into a summary with decisions and action items.</p><button className="ids-btn ids-btn--primary" onClick={doEnhance}>✦ Enhance notes</button></div>
        : <article className="gn__doc" data-testid="enhanced">
          {e.summary.length > 0 && <section><h2>Summary</h2><ul>{e.summary.map((s, i) => <li key={i} className="gn__ai">{s}</li>)}</ul></section>}
          {e.sections.map(s => <section key={s.heading}><h2>{s.heading}</h2><ul>{s.lines.map((l, i) => <li key={i} className={l.mine ? "gn__mine" : "gn__ai"} data-mine={l.mine}>{l.text}{l.detail && <ul><li className="gn__ai">{l.detail}</li></ul>}</li>)}</ul></section>)}
          {e.decisions.length > 0 && <section><h2>Decisions</h2><ul>{e.decisions.map((d, i) => <li key={i} className="gn__ai">{d}</li>)}</ul></section>}
          {e.actions.length > 0 && <section><h2>Action items</h2><ul className="gn__checks" data-testid="actions">{e.actions.map((a, i) => <li key={i} className={done.has(a.text) ? "done" : ""}><label><input type="checkbox" checked={done.has(a.text)} onChange={() => onChange({ done: done.has(a.text) ? [...done].filter(x => x !== a.text) : [...done, a.text] })} /> <span>{a.text}</span></label>{a.owner && <em className="gn__tag">{a.owner}</em>}{a.due && <em className="gn__tag gn__tag--due">{a.due}</em>}</li>)}</ul></section>}
          {e.questions.length > 0 && <section><h2>Open questions</h2><ul>{e.questions.map((x, i) => <li key={i} className="gn__ai">{x}</li>)}</ul></section>}
          <div className="tb" style={{ marginTop: 24 }}><button className="iconbtn" onClick={doEnhance}>Re-enhance</button><button className="iconbtn" onClick={async () => { await navigator.clipboard.writeText(md).catch(() => {}); setCopied(true); setTimeout(() => setCopied(false), 1500); }}>{copied ? "Copied!" : "Copy as Markdown"}</button>
            <a className="iconbtn" style={{ textDecoration: "none", color: "inherit" }} download={`${(note.title || "meeting").replace(/[^\w-]+/g, "-")}.md`} href={`data:text/markdown;charset=utf-8,${encodeURIComponent(md)}`}>Download .md</a></div>
          <p className="ids-muted" style={{ fontSize: 12.5 }}>Your words are in black; text drawn from the transcript is gray.</p></article>)}
    </div>
    <div className="gn__bar">{chat.length > 0 && <div className="gn__chat" data-testid="chat">{chat.map((c, i) => <div key={i}><b>{c.q}</b><p>{c.a}</p></div>)}</div>}
      <form onSubmit={submit} className="gn__ask"><input aria-label="Ask about this meeting" placeholder="Ask anything about this meeting…" value={q} onChange={ev => setQ(ev.target.value)} /><button className="iconbtn" type="submit">Ask</button>
        <button type="button" className="ids-btn ids-btn--primary" onClick={doEnhance} disabled={!note.notes.trim() && !note.transcript.trim()}>✦ Enhance notes</button></form></div></div>;
}
