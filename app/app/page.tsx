import { currentUser } from "@/lib/session";
import { Workspace } from "@/components/notes/Workspace";
export default async function AppHome() { const u = (await currentUser())!; return <Workspace userId={u.id} />; }
