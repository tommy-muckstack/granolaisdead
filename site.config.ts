import type { Site } from "@/lib/site-types";
const GH = "https://github.com/tommy-muckstack/granolaisdead";
export const site: Site = {
  slug: "granolaisdead", name: "GranolaIsDead", replaces: "Granola", theme: "granola",
  glyph: "M7 16 C7 11 9 8 12 8 C15 8 17 11 17 16 M9 16 H15 M12 5 V8",
  nav: [{ label: "Product", id: "product" }, { label: "Use cases", id: "solutions" }, { label: "Resources", id: "resources" }, { label: "Pricing", id: "pricing" }],
  cta: "Take notes, it's free",
  hero: { variant: "split", eyebrow: "Free · Open source · No bot in your call", title: ["Notes that write", "themselves, mostly."], subtitle: "Jot down what matters while you talk. GranolaIsDead weaves in what was said: a summary, decisions and action items, with your own words kept in black and the rest in gray. All local, no meeting bot, no subscription.",
    primary: { label: "Start a note", href: "/login" }, secondary: { label: "See pricing", href: "/#pricing" }, shot: "enhanced.png", shotAlt: "An enhanced meeting note with a summary, bullets in black and gray, decisions and action items with owners" },
  audience: "Used for 1:1s, stand-ups, customer calls, interviews, and every meeting where you'd rather listen than type",
  stepsTitle: "From a messy call to clean notes",
  steps: [{ t: "Jot", d: "Type rough notes as the meeting happens, in your own shorthand. No structure needed." }, { t: "Capture", d: "Record with your browser's speech recognition, or paste a transcript from anywhere." }, { t: "Enhance", d: "One click merges your notes with the transcript into sections that fit your template." }, { t: "Ask", d: "Ask the meeting a question and get the lines that answer it." }],
  rows: [
    { id: "product", k: "Your notes first", h: "Your words stay yours", p: "Notes you typed show in black and anything pulled from the transcript is gray, so you can always tell who said what. Templates for 1:1s, stand-ups, customer discovery and interviews shape the sections.", img: "enhanced.png", alt: "An enhanced note where the user's lines are black and the added details are gray", cta: "See an enhanced note" },
    { id: "capture", k: "Capture", h: "Record, paste, or both", p: "Press record to transcribe from your microphone in the browser, or paste a transcript from your call tool. Speaker labels like “Maya:” are used to assign action items.", img: "transcript.png", alt: "The transcript tab with speaker-labeled lines and recording controls", cta: "Open the transcript tab" },
    { id: "actions", k: "Actions", h: "Decisions and to-dos, pulled out for you", p: "Phrases like “I’ll send”, “we agreed” and “by Friday” become decisions and action items with an owner and due date. Tick them off right in the note.", img: "actions.png", alt: "A list of action items with owner and due-date tags and checkboxes", cta: "See action items" },
    { id: "ask", k: "Ask", h: "Ask the meeting a question", p: "“Who is booking the legal review?” Search across your notes and the transcript and get the exact lines back, with speakers, no guessing.", img: "ask.png", alt: "A question typed into the ask bar with the matching transcript line shown as the answer", cta: "Ask a question" },
  ],
  statsTitle: "Real numbers, no fine print",
  stats: [{ b: "$0", s: "for every plan we replace" }, { b: "0 bots", s: "joining your calls" }, { b: "100% local", s: "notes stay on your device" }, { b: "Apache-2.0", s: "self-host it, fork it, change it" }],
  integrations: { title: "Take your notes anywhere", text: "Copy any note as Markdown or download it as a .md file for Notion, Obsidian, email or your docs. Calendar and CRM sync are on the roadmap." },
  pricing: { title: "What you'd pay for AI meeting notes", vendor: "Granola", asOf: "October 2026", plans: [{ name: "Business", perSeatMonth: 14, note: "per user, billed monthly" }, { name: "Enterprise", perSeatMonth: 35, note: "per user, SSO and admin controls" }], seats: 5,
    footnote: "Granola's free plan keeps a limited number of meetings and hides older notes; paid plans are per active user. Self-hosting has your own hosting costs; a small instance fits in free tiers.", featuresTitle: "Every feature, no plan gates",
    features: [{ name: "Unlimited meetings and history", plan: "Business" }, { name: "Templates for common meetings", plan: "Free" }, { name: "Action items and decisions", plan: "Business" }, { name: "Ask questions about a meeting", plan: "Business" }, { name: "Markdown export", plan: "Business" }, { name: "Org-wide privacy controls", plan: "Enterprise" }] },
  finalCta: { title: "Your next meeting can write its own notes.", sub: "Open a note, jot, enhance. No card, no meeting bot." },
  footer: [
    { title: "Product", links: [{ label: "Notes", href: "/#product" }, { label: "Capture", href: "/#capture" }, { label: "Actions", href: "/#actions" }, { label: "Pricing", href: "/#pricing" }] },
    { title: "Get started", links: [{ label: "Log in", href: "/login" }, { label: "Try the demo account", href: "/login" }, { label: "Price comparison", href: "/#pricing" }] },
    { title: "Open source", links: [{ label: "GitHub", href: GH }, { label: "Apache-2.0 license", href: GH + "/blob/main/LICENSE" }] },
    { title: "More IsDead apps", links: [{ label: "CalendlyIsDead", href: "/calendlyisdead" }, { label: "GrammarlyIsDead", href: "/grammarlyisdead" }, { label: "TypeformIsDead", href: "/typeformisdead" }, { label: "DocuSignIsDead", href: "/docusignisdead" }] },
  ],
  trademark: "GranolaIsDead is an independent open-source project. It is not affiliated with, endorsed by or sponsored by Granola Labs, Inc. Granola is a trademark of its owner. Always get consent before recording a conversation.",
  repo: GH,
};
