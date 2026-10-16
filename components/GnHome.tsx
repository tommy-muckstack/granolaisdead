import Link from "next/link";
import "./pk.css";
import "./gnhome.css";
import { GH, REQUIREMENTS } from "@/site.config";

// Granola look-alike marketing page. GranolaIsDead is a native Mac app: every CTA downloads it via /download.
export const GnMark = ({ s = 22 }: { s?: number }) => <svg width={s} height={s} viewBox="0 0 24 24" aria-hidden><path d="M12 3a9 9 0 100 18 9 9 0 01-4-7.5 5 5 0 019.5-1.5 3 3 0 11-4.5-2.5 1.8 1.8 0 10-1.5 3" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" /></svg>;
export function GnNav() {
  return <header className="gn-nav"><Link href="/" className="lg"><GnMark /> granola</Link><nav><Link href="/#features">Features</Link><Link href="/pricing">Pricing</Link><a href={GH}>GitHub</a></nav><span className="sp" /><a href={GH} className="a">View source</a><Link href="/download" className="b"><i /><span className="dk"> Download</span><span className="ga">Get the app</span></Link></header>;
}
type FLink = [string, string];
const FCOL: [string, FLink[]][] = [
  ["Product", [["Download for Mac", "/download"], ["Features", "/#features"], ["Pricing", "/pricing"], ["Release notes", GH + "/releases"]]],
  ["Open source", [["Source code", GH], ["Report an issue", GH + "/issues"], ["Apache-2.0 license", GH + "/blob/main/LICENSE"]]],
  ["IsDead apps", [["YourAppIsDead", "https://yourappisdead.com"], ["CleanShotXIsDead", "https://yourappisdead.com/cleanshotxisdead"], ["NotionIsDead", "https://yourappisdead.com/notionisdead"]]],
  ["Requirements", [["macOS 14.2 or later", "/download"], ["Apple silicon & Intel", "/download"]]],
];
const FA = ({ l: [label, href] }: { l: FLink }) => href.startsWith("/") ? <Link href={href}>{label}</Link> : <a href={href}>{label}</a>;
export function GnFoot() {
  return <footer className="gn-foot"><div className="cols">{FCOL.map(([t, ls]) => <div key={t}><h5>{t}</h5>{ls.map(l => <FA key={l[0]} l={l} />)}</div>)}</div><div className="soc"><i /><i /><i /><span>© GranolaIsDead contributors 2026</span></div><div className="wm"><GnMark s={190} /><b>granola</b></div><p className="note">GranolaIsDead is an independent open-source project, not affiliated with or endorsed by Granola, Inc. Source: github.com/tommy-muckstack/granolaisdead (Apache-2.0)</p></footer>;
}
const APPS = ["Zoom", "Google Meet", "Teams", "Slack Huddles", "Webex", "FaceTime", "Discord", "Whereby", "Tuple", "Around", "Riverside", "In person"];
const FEATS: [number, string, string][] = [[605, "Humans in the room, not bots", "GranolaIsDead doesn't join your meeting. It records your mic and your Mac's system audio in the background while you stay present."], [1395, "Works with all meeting apps", "Zoom, Meet, Teams, Huddles, FaceTime or a browser tab: if your Mac can hear it, GranolaIsDead can transcribe it."], [2185, "Private by default", "Transcription runs on-device with Parakeet and notes are stored on your Mac. No account, no cloud sync, nothing to sign up for."], [2970, "Knows who said what", "Speaker separation splits the transcript by voice, so action items land on the right person and you can see who agreed to what."], [3840, "Knows what's coming up", "GranolaIsDead reads your calendar to list today's meetings and notices when a call starts, so recording is one click away."]];
export function GnHome() {
  return <div className="gnh pk">
    <GnNav />
    <section className="hero"><a href={GH} className="badge"><b>New</b> Native Mac app, free &amp; open source →</a><h1>The AI notepad for back-to-back meetings</h1><p>Notes, actions and memory.<br />Without a meeting bot.</p><Link href="/download" className="dl">Download for free ↓</Link><small>{REQUIREMENTS} · <a href={GH} style={{ textDecoration: "underline" }}>Source on GitHub</a></small>
      <div className="art"><i className="a" /><i className="b" /><div className="win"><div className="d"><u /><u /><u /></div><h4>Q3 GTM sync</h4><span className="chip">Today · 4</span><ul><li>Agreed to narrow Q3 focus to mid-market financial services buyers</li><li>SMB deprioritized for the quarter</li><li>Follow-up scheduled for Tuesday</li></ul></div><div className="vid" /></div></section>
    <section className="eff"><h2>Effortless notes,<br />enhanced instantly.</h2>{[["Uses your computer audio, so doesn't join as a bot", 340], ["Live transcription and enhanced notes, generated on your Mac", 428], ["Works with Zoom, Google Meet, Teams and every other meeting app.", 505]].map(([t, y]) => <div key={String(t)} className="ln" style={{ top: Number(y) }}><i />{t}</div>)}</section>
    <section className="doers"><h2>For the doers</h2></section>
    <section className="trusted"><p>Works with every meeting app</p><div className="lg">{APPS.map(l => <b key={l}>{l}</b>)}</div></section>
    <section className="helps" id="features"><h2>GranolaIsDead helps you before, during and after your meetings.</h2>
      <ul className="tabs"><li className="on">Before the meeting</li><li>In the meeting</li><li>After the meeting</li></ul>
      {[["See what's coming up", "GranolaIsDead reads your calendar and lists your upcoming meetings, then detects when a call starts so you can start recording in one click.", 525, 640], ["Give your full attention", "Don't choose between listening and taking good notes. Write down as much or as little as you like while the live transcript fills in the rest.", 1347, 1465], ["Post-meeting admin, done", "Enhanced notes, decisions and action items are ready the moment the meeting ends, shaped by the template you picked.", 2172, 2265]].map(([t, d, ty, iy], i) => <div key={i}><div className="ct" style={{ top: Number(ty) }}><h3>{t}</h3><p>{d}</p></div><div className={"card c" + i} style={{ top: Number(iy) }}><div className="nw"><div className="d"><u /><u /><u /></div><h4>Northwind Sync</h4><span className="chip">Today · 2</span><em>Write notes…</em></div></div></div>)}</section>
    <section className="lime"><small>Chat with a meeting</small><h2>Ask what<br />was really<br />said</h2><div className="box"><i /><span className="pill">Customer calls</span></div></section>
    <section className="testi"><h2>Built for busy people<br />with busy days</h2><div className="cs">{[["On-device", "Your audio never leaves your Mac. Parakeet transcribes it live, Apple's on-device model writes the notes.", "Parakeet + Apple Foundation Models", "Runs locally on macOS 26"], ["Open source", "No account, no subscription, no seat count. Read the code, build it yourself, change anything.", "Apache-2.0", "github.com/tommy-muckstack/granolaisdead"]].map(([l, q, n, r]) => <div key={n}><b>{l}</b><p>{q}</p><i /><small>{n}<br /><span>{r}</span></small></div>)}</div></section>
    <section className="feat"><small>Features</small><h2>Works everywhere<br />you do, how you do</h2><Link href="/download" className="dl s">Download for free ↓</Link>
      {FEATS.map(([y, t, d], i) => <div key={t}><div className="row" style={{ top: y }}><h3>{t}</h3><p>{d}</p></div><div className={"shot s" + i} style={{ top: y + (i === 3 ? 220 : i === 4 ? 165 : 140) }}><i /></div></div>)}</section>
    <section className="mcp" id="models"><small>Bring your own model</small><h2>Your notes, your<br />model, your Mac</h2><Link href="/download" className="dl s">Download for free ↓</Link><div className="rw"><h3>Enhanced notes run on-device. A cloud model is optional.</h3><p>On macOS 26 GranolaIsDead uses Apple Foundation Models, so nothing leaves your Mac. Prefer Claude or OpenAI? Add your own API key and your notes go straight from your Mac to the provider you picked. Templates shape every note.</p></div><div className="ap">{[0, 1, 2, 3, 4, 5, 6, 7].map(i => <i key={i} className={"k" + i} />)}</div></section>
    <section className="cta"><div className="in"><h2>Unlimited meeting notes for free</h2><p>Take as many notes as you&apos;d like. No account, no subscription, no 30-day limit. Updates install themselves.</p><div className="bs"><Link href="/download" className="dl s">Download for free ↓</Link><Link href="/pricing" className="vp">View pricing</Link></div></div></section>
    <GnFoot />
  </div>;
}
