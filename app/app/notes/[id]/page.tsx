import { currentUser } from "@/lib/session";
import { Workspace } from "@/components/notes/Workspace";
export default async function NotePage({ params }: { params: Promise<{ id: string }> }) { const u = (await currentUser())!; return <Workspace userId={u.id} noteId={(await params).id} />; }
