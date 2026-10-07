import { redirect } from "next/navigation";
import { supabaseServer } from "@/lib/supabase-server";

export const instant = false;

export default async function Home() {
  const supabase = await supabaseServer();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("ruolo, nome")
    .eq("id", user.id)
    .single();

  return (
    <main style={{ maxWidth: 480, margin: "80px auto", fontFamily: "sans-serif" }}>
      <h1>CRM Special Energy</h1>
      {profile ? (
        <p>Ciao {profile.nome} — ruolo: <b>{profile.ruolo}</b></p>
      ) : (
        <p>Account senza profilo assegnato. Contatta un amministratore.</p>
      )}
    </main>
  );
}
