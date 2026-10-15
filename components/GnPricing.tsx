import Link from "next/link";
import "./pk.css";
import "./gnhome.css";
import "./gnpricing.css";
import { GnNav, GnFoot } from "./GnHome";

type Cell = 0 | 1 | string;
const CATS: [string, number, [string, Cell, Cell, Cell][]][] = [["CAPTURE & NOTES", 56.45, [["AI meeting notes", 1, 1, 1], ["Bot-free, device-audio capture", 1, 1, 1], ["Desktop, iOS, Android & Apple Watch apps", 1, 1, 1], ["Speaker tagging", 1, 1, 1], ["Customized note templates", 1, 1, 1], ["Multi-language support", 1, 1, 1], ["Recipes", 1, 1, 1], ["Pre-meeting briefs", 0, 1, 1], ["Follow-up mails", 0, 1, 1], ["Workspace-wide dictionary", 0, 1, 1], ["Let people know you're using the app", "Per user", "Per user", "Admin-enforceable"]]], ["HISTORY & SEARCH", 53, [["Meeting history", "30 days", "Unlimited", "Unlimited"], ["AI chat across meetings", "Auto only", "Auto + model selection", "Auto + model selection"], ["Workspace usage analytics", 0, 0, 1]]], ["COLLABORATION & INTEGRATIONS", 60, [["Shared folders", 1, 1, 1], ["Integrations with chat tools", 1, 1, 1], ["Integrations with docs and CRM tools", 0, 1, 1], ["Advanced integrations", 0, 0, 1], ["MCP connectors for assistants", "Personal notes only", "Personal and public workspace notes", "Admin-configurable workspace notes"], ["API access", 0, 1, 1], ["Admin controls for connectors", 0, 0, 1], ["Centralized billing & user management", 0, 1, 1]]], ["TRUST & CONTROL", 57.5, [["Configurable transcript retention", "Per user", "Per user", "Workspace-wide admin policy"], ["Workspace-wide sharing settings", 0, 1, 1], ["Model training opt-out", "Per user", "Per user", "Workspace-wide"], ["Audio deleted after transcription", 1, 1, 1], ["Security attestation", 1, 1, 1], ["Regulated workspace mode", 0, 0, 1], ["DPA available", 1, 1, 1], ["Single sign-on", 0, 0, 1], ["Group provisioning", 0, 0, 1], ["Device management", 0, 0, 1], ["Audit API", 0, 0, 1]]], ["SUPPORT", 57, [["Join Labs (early access)", 1, 1, 1]]]];
const Ck = () => <span className="ck"><svg width="12" height="12" viewBox="0 0 12 12"><path d="M2.5 6.3l2.3 2.3 4.7-5" fill="none" stroke="#5e6b1c" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg></span>;
const cell = (c: Cell) => c === 1 ? <Ck /> : c === 0 ? <span className="dash">–</span> : <span className="tx">{c}</span>;
const Li = ({ children, bold }: { children: React.ReactNode; bold?: boolean }) => <li className={bold ? "bd" : ""}><Ck />{children}</li>;
const FAQ = ["What's the difference between the plans?", "What admin controls will I have?", "What are your integration capabilities?", "Do you train any models on my data?", "Is the product SOC 2 / HIPAA compliant?", "Does it support SSO?", "What SSO providers are supported?", "How do you notify other participants that notes are being taken?"];
const TW = [
  { x: 118, y: 5924, h: 297 }, { x: 118, y: 6242, h: 280 }, { x: 530, y: 5906, h: 262 }, { x: 530, y: 6191, h: 480 }, { x: 933, y: 5906, h: 312 }, { x: 933, y: 6247, h: 206 },
];

export function GnPricing() {
  return (
    <div className="gnh pk gpr">
      <GnNav />
      <h1 className="t">Notes how you wanna</h1>
      <p className="sub">Pick the plan that is right for you and your team, so everyone can be on the same page.</p>
      <div className="plans">
        <div className="pl"><h2>Basic</h2><p className="d">Great for a free taste of the app</p><div className="pr"><b>$0</b><span>per user per month</span></div><a className="dl"><i className="ap" />Download for Mac</a>
          <ul><Li>AI meeting notes</Li><Li>Limited meeting history</Li><Li>AI chat within and across meetings</Li><Li>Shared folders for collaboration</Li><Li>Customized note templates</Li><Li>Multi-language support</Li><Li>Opt out of model training at any time</Li></ul></div>
        <div className="pl"><h2>Business</h2><p className="d">Great for individuals or small teams</p><div className="pr"><b>$14</b><span>per user per month</span></div><a className="dl"><i className="ap" />Download for Mac</a>
          <ul><Li bold>Everything in Basic, plus</Li><Li>Unlimited meeting notes and history</Li><Li>Access to advanced AI thinking models and features</Li><Li>Advanced integrations with docs, CRM and chat tools</Li><Li>Centralized billing & user management</Li><Li>MCP integration in all your apps</Li><Li>API access</Li></ul></div>
        <div className="pl"><h2>Enterprise</h2><p className="d">Great for larger companies</p><div className="pr"><b>$35</b><span>per user per month</span></div><a className="dl">Sign up in app</a><a className="dl lt">Learn more</a>
          <ul><Li bold>Everything included in Business</Li><Li>Enterprise-grade security & admin controls</Li><Li>Single sign-on (SSO)</Li><Li>Priority support and usage analytics</Li><Li>Org-wide auto-deletion periods</Li><Li>Admin controls for sharing & API access</Li><Li>Opt out of model training for everyone in your team</Li><Li>Org-wide notification that the app is being used</Li></ul></div>
      </div>
      <p className="co">A small share of every subscription goes to carbon removal through a climate partner.</p>
      <blockquote className="q">“As we rebuilt our product into an AI-native company, we needed tools that move fast without ever compromising accuracy. This one earned our trust by delivering precise, reliable summaries, and helped strengthen our written culture.”</blockquote>
      <div className="au"><i /><span><b>Alex Rivera</b><br />Founder and CEO, Northwind</span></div>
      <a className="cs2">Read the case study</a>
      <h2 className="cmp">Compare plans</h2>
      <table className="tb">
        <thead><tr><th>Features</th><th><b>Basic</b><span>Get started ›</span></th><th><b>Business</b><span>Get started ›</span></th><th><b>Enterprise</b><span>Learn more ›</span></th></tr></thead>
        <tbody>
          {CATS.map(([cat, rh, rows]) => [
            <tr key={cat} className="cat"><td colSpan={4}>{cat}</td></tr>,
            ...rows.map((r) => <tr key={cat + r[0]} style={{ height: rh }}><td>{r[0]}</td><td>{cell(r[1])}</td><td>{cell(r[2])}</td><td>{cell(r[3])}</td></tr>),
          ])}
          <tr style={{ height: 51 }}><td>Support level</td><td><span className="tx">Standard</span></td><td><span className="tx">Standard</span></td><td><span className="tx">Dedicated</span></td></tr>
        </tbody>
      </table>
      <h2 className="nt">Things worth noting</h2>
      <div className="faq">{FAQ.map((f, i) => <div key={f} className={"fq" + (i === 7 ? " last" : "")}><span>{f}</span><svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 5l4 4 4-4" fill="none" stroke="#1f1f1f" strokeWidth="1.4" /></svg></div>)}</div>
      <h2 className="rs">Resources</h2>
      <div className="rcs">{[["Security", "How we secure your data & privacy", "#5e6b1c"], ["Policies", "Everything you need to know over terms", "#6c8cd6"], ["Other FAQs", "All other questions you may have", "#8a63d2"]].map(([a, b, c]) => <div key={a} className="rc"><i style={{ background: c }} /><h3>{a}</h3><p>{b}</p></div>)}</div>
      <h2 className="ppl">What people are saying</h2>
      {TW.map((t, i) => <div key={i} className="tw" style={{ left: t.x, top: t.y, height: t.h }}><span className="av" /><b /><em /><s /><s /><s style={{ width: "60%" }} /><u /></div>)}
      <h2 className="hp">Helping the world's best product teams focus more on their meetings</h2>
      <div className="lgs">{["Linework", "Index", "Brix", "replica", "Lumable"].map((l) => <span key={l}>{l}</span>)}</div>
      <div className="gbox"><div className="win"><i /><i /><i /><h2>Ready for <em>calmer</em>, more productive meetings?</h2><p>Try it for a few meetings today. It's free to get started.</p><div className="bs"><a className="dl">Download for Mac</a><a className="dl lt">Download for Mobile</a></div></div></div>
      <div className="fw"><GnFoot /></div>
    </div>
  );
}
