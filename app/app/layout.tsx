import { redirect } from "next/navigation";
import { currentUser, entryRedirect } from "@/lib/session";
import { AppHeader } from "@/components/AppHeader";
export const dynamic = "force-dynamic";
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await currentUser();
  if (!user) redirect(entryRedirect("/app"));
  return <div className="app-root"><AppHeader user={user} />{children}</div>;
}
