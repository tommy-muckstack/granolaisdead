export type Template = "general" | "one-on-one" | "standup" | "customer" | "interview";
export const TEMPLATES: { id: Template; name: string; sections: { heading: string; keys: string[] }[] }[] = [
  { id: "general", name: "General meeting", sections: [{ heading: "Discussion", keys: [] }] },
  { id: "one-on-one", name: "1:1", sections: [
    { heading: "Updates", keys: ["update", "shipped", "finished", "progress", "working", "launched", "completed", "status"] },
    { heading: "Feedback", keys: ["feedback", "great", "improve", "better", "concern", "appreciate", "learned", "struggle"] },
    { heading: "Goals and growth", keys: ["goal", "career", "growth", "promotion", "learn", "skill", "quarter", "plan"] }] },
  { id: "standup", name: "Stand-up", sections: [
    { heading: "Yesterday", keys: ["yesterday", "finished", "shipped", "completed", "merged", "fixed", "done"] },
    { heading: "Today", keys: ["today", "working", "going", "next", "start", "will", "plan"] },
    { heading: "Blockers", keys: ["blocked", "blocker", "waiting", "stuck", "issue", "problem", "risk", "delay"] }] },
  { id: "customer", name: "Customer discovery", sections: [
    { heading: "Background", keys: ["team", "company", "role", "currently", "today", "process", "workflow", "use"] },
    { heading: "Pain points", keys: ["pain", "problem", "frustrat", "hard", "difficult", "slow", "expensive", "annoying", "manual", "wish"] },
    { heading: "Needs and requests", keys: ["need", "want", "would", "feature", "require", "must", "integrate", "pricing", "budget"] }] },
  { id: "interview", name: "Interview", sections: [
    { heading: "Experience", keys: ["experience", "worked", "years", "previous", "company", "role", "built", "led"] },
    { heading: "Strengths", keys: ["strength", "good", "great", "excellent", "skilled", "impressive", "strong"] },
    { heading: "Concerns", keys: ["concern", "weak", "gap", "unsure", "risk", "lack", "worried"] }] },
];
export type Line = { text: string; mine: boolean; detail?: string };
export type Section = { heading: string; lines: Line[] };
export type Action = { text: string; owner?: string; due?: string };
export type Enhanced = { summary: string[]; sections: Section[]; actions: Action[]; decisions: string[]; questions: string[]; generatedAt: number };
export type Note = { id: string; done?: string[]; title: string; template: Template; notes: string; transcript: string; enhanced?: Enhanced; createdAt: number; updatedAt: number };
