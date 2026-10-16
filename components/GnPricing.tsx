import { MeasuredPage } from "./m/MeasuredPage";
import pm from "./m/pricing390.json";
import "./pk.css";
import "./gnhome.css";
import "./gnpricing.css";
import { GnNav, GnFoot } from "./GnHome";
import type { Measured, MeasuredItem } from "./m/MeasuredPage";
import { DL, GH } from "@/site.config";

type Cell = 0 | 1 | string;
// Column 1 is GranolaIsDead (the free Mac app); columns 2-3 are a typical paid notetaker's plans, for comparison.
const CATS: [string, number, [string, Cell, Cell, Cell][]][] = [["CAPTURE & NOTES", 80, [["AI meeting notes", 1, 1, 1], ["Bot-free, device-audio capture", 1, 1, 1], ["Live transcription", "On-device (Parakeet)", 1, 1], ["You and them, labeled", 1, 1, 1], ["Customized note templates", 1, 1, 1], ["Chat with a meeting", 1, 1, 1], ["Upcoming meetings and meeting detection", 1, 1, 1], ["Pre-meeting briefs", 0, 1, 1], ["Follow-up emails", 0, 1, 1], ["Apps", "Mac", "Desktop & mobile", "Desktop & mobile"]]], ["HISTORY & PRIVACY", 80, [["Meeting history", "Unlimited", "Unlimited", "Unlimited"], ["Where notes live", "On your Mac", "Vendor cloud", "Vendor cloud"], ["AI model", "On-device, or your own Claude / OpenAI key", "Auto + model selection", "Auto + model selection"], ["Account required", "No", "Yes", "Yes"]]], ["COLLABORATION & INTEGRATIONS", 80, [["Shared folders", 0, 1, 1], ["Integrations with docs and CRM tools", 0, 1, 1], ["MCP connectors for assistants", 0, 1, 1], ["API access", 0, 1, 1], ["Single sign-on", 0, 0, 1], ["Centralized billing & user management", "No billing at all", 1, 1]]], ["SOURCE & UPDATES", 80, [["Open source", "Apache-2.0", 0, 0], ["Automatic updates", 1, 1, 1], ["Price", "$0", "$14 per user / mo", "$35 per user / mo"]]]];
const Ck = () => <span className="ck"><svg width="12" height="12" viewBox="0 0 12 12"><path d="M2.5 6.3l2.3 2.3 4.7-5" fill="none" stroke="#5e6b1c" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg></span>;
const cell = (c: Cell) => c === 1 ? <Ck /> : c === 0 ? <span className="dash">–</span> : <span className="tx">{c}</span>;
const Li = ({ children, bold }: { children: React.ReactNode; bold?: boolean }) => <li className={bold ? "bd" : ""}><Ck />{children}</li>;
const FAQ: [string, string][] = [["Is it really free?", "Yes. Every feature, no plans, no seats."], ["Do I need an account?", "No. Download it, open it, record."], ["Does it join my calls as a bot?", "Never. It records your Mac's mic and system audio."], ["Where is my data stored?", "On your Mac. There is no sync and no server."], ["Which AI writes the notes?", "Apple's on-device model on macOS 26, or your own Claude or OpenAI key. On older macOS without a key, a basic built-in summary."], ["What do I need to run it?", "macOS 14.2 or later, on Apple silicon or Intel."], ["Is there a Windows or iPhone app?", "No. GranolaIsDead is a Mac app only."], ["How do I let other participants know notes are being taken?", "Tell them at the start of the call. Always get consent before recording."]];
const FA = { fontFamily: "var(--ids-font-sans)", fontSize: 14, lineHeight: "20px", color: "#555", width: 330, textAlign: "right" } as const;
// Mobile (<=900px) layout: Granola's measured pricing page, with copy rewritten for GranolaIsDead and the sections that only describe Granola cut out.
const MTEXT: Record<number, string> = { 537: "Ready for calmer,", 538: "more productive", 287: "Download", 288: "Notes how you wanna", 289: "Every feature is free. Here's what paid", 290: "notetakers charge for the same notes.", 291: "GranolaIsDead", 292: "Free and open source, forever", 294: "no account, no seats", 295: "Download for Mac", 297: "Unlimited meeting history", 298: "Chat with any meeting", 299: "You and them, labeled", 301: "Live on-device transcription", 302: "Nothing leaves your Mac by default", 303: "Paid notetaker: Business", 304: "What paid notetakers charge teams", 307: "Download free instead", 308: "Everything in the free tier, plus", 317: "Paid notetaker: Enterprise", 318: "What they charge larger companies", 321: "Download free instead", 322: "View source", 323: "Everything in the Business plan", 332: "Org-wide notification that the app is", 475: "Source code", 476: "Read every line on GitHub", 477: "License", 478: "Apache-2.0, use it however you like", 479: "Issues", 480: "Questions, bugs and ideas", 540: "Try it in your next meeting.", 541: "Free, no account needed.", 542: "Download for Mac", 543: "View source on GitHub", 578: "© GranolaIsDead" };
const MLINK: Record<string, string> = { "View source": GH, "Source code": GH, "Read every line on GitHub": GH, "License": GH + "/blob/main/LICENSE", "Apache-2.0, use it however you like": GH + "/blob/main/LICENSE", "Issues": GH + "/issues", "Questions, bugs and ideas": GH + "/issues", "View source on GitHub": GH, "Pricing": "/pricing", "Download for Mac": "/download", "YourAppIsDead": "https://yourappisdead.com", "\u00a0": "/" };
// y-ranges (px in the 390 layout) to remove: Granola's carbon note, customer quote, plan table and FAQ; then its tweets and customer logos.
const MCUT: [number, number][] = [[2000, 6760], [7360, 9220]];
// Granola's buttons that were plain text in the capture: make them real download links.
const MHREF = new Set([295, 307, 321, 542]);
// Granola's nav hamburger (no menu here) and everything from its footer down.
const MDROP = new Set([3, 278, 283]); // hamburger, the "calmer" image pill, the phone icon
const FOOT_Y = 9640;
const mt = (x: number, y: number, t: string, o: Partial<MeasuredItem> = {}): MeasuredItem => ({ k: "t", x, y, w: 200, h: 19, fs: "14px", lh: "18px", fw: "400", c: "rgb(41, 41, 41)", ff: "melange", ta: "left", t, z: 3, ...o });
// Our own footer in place of Granola's 33 links (MLINK maps each label to a real URL).
const MFOOT = (y: number): MeasuredItem[] => [
  mt(16, y, "GranolaIsDead", { fs: "24px", lh: "28px", ff: "quadrant", h: 32 }),
  mt(16, y + 52, "Download for Mac", { href: 1, td: "underline" }), mt(16, y + 84, "Source code", { href: 1, td: "underline" }),
  mt(16, y + 116, "Issues", { href: 1, td: "underline" }), mt(16, y + 148, "License", { href: 1, td: "underline" }),
  mt(16, y + 180, "YourAppIsDead", { href: 1, td: "underline" }),
  mt(16, y + 236, "Not affiliated with Granola, Inc. Apache-2.0.", { c: "rgb(114, 114, 110)", fs: "12px", w: 358 }),
];
function mobile(d: Measured): Measured {
  const gone = (p: number) => MCUT.reduce((a, [y0, y1]) => a + Math.min(Math.max(p - y0, 0), y1 - y0), 0);
  const kept = d.items.map((it, n) => (MTEXT[n] ? { ...it, t: MTEXT[n] } : it)).map((it, n) => (MHREF.has(n) ? { ...it, href: 1 } : it))
    .filter((it, n) => !MDROP.has(n) && it.y < FOOT_Y);
  // A transparent link over the logo so the mobile page has a way home.
  kept.push(mt(16, 13.5, "\u00a0", { w: 147, h: 28, href: 1, ff: undefined }));
  const footY = FOOT_Y + 20;
  const all = [...kept, ...MFOOT(footY)];
  const H = footY + 300;
  const items = all
    .filter((it) => !MCUT.some(([y0, y1]) => it.y >= y0 && it.y < y1))
    .map((it) => { const y = it.y - gone(it.y); return { ...it, y, h: it.y + it.h - gone(it.y + it.h) - y }; });
  return { ...d, H: H - gone(H), items };
}
const TW = [
  { x: 118, y: 5924, h: 297 }, { x: 118, y: 6242, h: 280 }, { x: 530, y: 5906, h: 262 }, { x: 530, y: 6191, h: 480 }, { x: 933, y: 5906, h: 312 }, { x: 933, y: 6247, h: 206 },
];

export function GnPricing() {
  return (
    <><MeasuredPage data={mobile(pm as unknown as Measured)} className="gn-pm" display={/quadrant/} link={(i) => MLINK[i.t ?? ""]} />
    <div className="gnh pk gpr mp-desk">
      <GnNav />
      <h1 className="t">Notes how you wanna</h1>
      <p className="sub">Every feature is free. Here&apos;s what paid AI notetakers charge for the same meeting notes.</p>
      <div className="plans">
        <div className="pl"><h2>GranolaIsDead</h2><p className="d">Every feature, free and open source</p><div className="pr"><b>$0</b><span>no account, no seats</span></div><a href={DL} className="dl"><i className="ap"><svg width="16" height="16" viewBox="0 0 24 24" fill="#fff" aria-hidden><path d="M16.7 12.6c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.8-3.5.8s-1.8-.8-3-.8c-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7 2.1-1.1 2.8-2.2c.9-1.3 1.2-2.5 1.3-2.6-.1 0-2.5-1-2.5-3.8zM14.4 5.8c.6-.8 1.1-1.8.9-2.8-.9 0-2 .6-2.6 1.4-.6.7-1.1 1.7-.9 2.7 1 .1 2-.5 2.6-1.3z" /></svg></i><span className="dkd">Download for Mac</span><span className="mbd">Download for Mac</span></a>
          <ul><Li>Live on-device transcription</Li><Li>Unlimited meeting history</Li><Li>Enhanced notes with templates</Li><Li>You and them, labeled</Li><Li>Chat with any meeting</Li><Li>Upcoming meetings and meeting detection</Li><Li>On-device AI, or your own Claude / OpenAI key</Li></ul></div>
        <div className="pl"><h2>Paid notetaker: Business</h2><p className="d">What paid notetakers charge small teams</p><div className="pr"><b>$14</b><span>per user per month</span></div><a href={DL} className="dl"><i className="ap"><svg width="16" height="16" viewBox="0 0 24 24" fill="#fff" aria-hidden><path d="M16.7 12.6c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.8-3.5.8s-1.8-.8-3-.8c-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7 2.1-1.1 2.8-2.2c.9-1.3 1.2-2.5 1.3-2.6-.1 0-2.5-1-2.5-3.8zM14.4 5.8c.6-.8 1.1-1.8.9-2.8-.9 0-2 .6-2.6 1.4-.6.7-1.1 1.7-.9 2.7 1 .1 2-.5 2.6-1.3z" /></svg></i><span className="dkd">Download free instead</span><span className="mbd">Download free instead</span></a>
          <ul><Li bold>Everything in the free tier, plus</Li><Li>Unlimited meeting notes and history</Li><Li>Access to advanced AI thinking models and features</Li><Li>Advanced integrations with docs, CRM and chat tools</Li><Li>Centralized billing & user management</Li><Li>MCP integration in all your apps</Li><Li>API access</Li></ul></div>
        <div className="pl"><h2>Paid notetaker: Enterprise</h2><p className="d">What they charge larger companies</p><div className="pr"><b>$35</b><span>per user per month</span></div><a href={DL} className="dl">Download free instead</a><a href={GH} className="dl lt">View source</a>
          <ul><Li bold>Everything in the Business plan</Li><Li>Enterprise-grade security & admin controls</Li><Li>Single sign-on (SSO)</Li><Li>Priority support and usage analytics</Li><Li>Org-wide auto-deletion periods</Li><Li>Admin controls for sharing & API access</Li><Li>Opt out of model training for everyone in your team</Li><Li>Org-wide notification that the app is being used</Li></ul></div>
      </div>
      <p className="co">Typical paid AI-notetaker list prices, October 2026. GranolaIsDead has no paid plan.</p>
      <blockquote className="q">“Every feature is in the free download. No seats, no plans, no 30-day history limit, and nothing leaves your Mac unless you choose a cloud model.”</blockquote>
      <div className="au"><i /><span><b>GranolaIsDead</b><br />Apache-2.0, open source</span></div>
      <a href={GH} className="cs2">Read the code</a>
      <h2 className="cmp">Compare plans</h2>
      <table className="tb">
        <thead><tr><th>Features</th><th><b>GranolaIsDead</b><a href={DL} style={{ float: "right", color: "#555" }}>Download ›</a></th><th><b>Paid: Business</b></th><th><b>Paid: Enterprise</b></th></tr></thead>
        <tbody>
          {CATS.map(([cat, rh, rows]) => [
            <tr key={cat} className="cat"><td colSpan={4}>{cat}</td></tr>,
            ...rows.map((r) => <tr key={cat + r[0]} style={{ height: rh }}><td>{r[0]}</td><td>{cell(r[1])}</td><td>{cell(r[2])}</td><td>{cell(r[3])}</td></tr>),
          ])}
          <tr style={{ height: 51 }}><td>Support level</td><td><a href={GH + "/issues"} className="tx">Community (GitHub issues)</a></td><td><span className="tx">Standard</span></td><td><span className="tx">Dedicated</span></td></tr>
        </tbody>
      </table>
      <h2 className="nt">Things worth noting</h2>
      <div className="faq">{FAQ.map(([q, ans], i) => <div key={q} className={"fq" + (i === 7 ? " last" : "")}><span style={i === 7 ? { width: 400 } : undefined}>{q}</span><small style={FA}>{ans}</small></div>)}</div>
      <h2 className="rs">Resources</h2>
      <div className="rcs">{[["Source code", "Read every line on GitHub", "#5e6b1c", GH], ["License", "Apache-2.0, use it however you like", "#6c8cd6", GH + "/blob/main/LICENSE"], ["Issues", "Questions, bugs and ideas", "#8a63d2", GH + "/issues"]].map(([a, b, c, h]) => <a key={a} href={h} className="rc" style={{ display: "block", color: "inherit" }}><i style={{ background: c }} /><h3>{a}</h3><p>{b}</p></a>)}</div>
      <h2 className="ppl">Built in the open</h2>
      {TW.map((t, i) => <div key={i} className="tw" style={{ left: t.x, top: t.y, height: t.h }}><span className="av" /><b /><em /><s /><s /><s style={{ width: "60%" }} /><u /></div>)}
      <h2 className="hp">Works with every meeting app you already use</h2>
      <div className="lgs">{["Zoom", "Meet", "Teams", "Slack", "Webex"].map((l) => <span key={l}>{l}</span>)}</div>
      <div className="gbox"><div className="win"><i /><i /><i /><h2>Ready for <em>calmer</em>, more productive meetings?</h2><p>Try it in your next meeting. It&apos;s free, no account needed.</p><div className="bs"><a href={DL} className="dl">Download for Mac</a><a href={GH} className="dl lt">View source on GitHub</a></div></div></div>
      <div className="fw"><GnFoot /></div>
    </div></>
  );
}
