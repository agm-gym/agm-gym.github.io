// AGM Gym : envoie les notifications (messages, nouveaux événements, sélections en compétition)
// Secret à définir dans Supabase > Edge Functions > Secrets : VAPID_PRIVATE
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const VAPID_PUBLIC = "BMGvj_FNC9jj82yo0CQIMD1B9JgaIf-gMLFdqkqIHhEtkvtmyCcwKARwbYFvHvn_96O1xwL152tUNfgJy_8tbBA";
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
webpush.setVapidDetails("mailto:academie.gym.med@gmail.com", VAPID_PUBLIC, Deno.env.get("VAPID_PRIVATE")!);

const FRESH_MS = 10 * 60 * 1000; // on ne notifie que ce qui vient d'être créé
const fresh = (iso?: string) => !iso || Date.now() - new Date(iso).getTime() < FRESH_MS;
const cut = (s: string, n: number) => (s.length > n ? s.slice(0, n - 1) + "…" : s);

async function approvedParents(): Promise<Set<string>> {
  const { data } = await sb.from("profiles").select("id").eq("role", "parent").eq("approved", true);
  return new Set((data ?? []).map((p) => p.id));
}
async function coaches(): Promise<string[]> {
  const { data } = await sb.from("profiles").select("id").eq("role", "coach");
  return (data ?? []).map((p) => p.id);
}
async function parentsOfGroups(groups: string[] | null): Promise<string[]> {
  const ok = await approvedParents();
  if (!groups) return [...ok];
  const { data } = await sb.from("kids").select("parent_id").in("grp", groups);
  return [...new Set((data ?? []).map((k) => k.parent_id))].filter((id) => ok.has(id));
}

Deno.serve(async (req) => {
  const { type, id } = await req.json().catch(() => ({}));
  if (!type || !id) return new Response("bad request", { status: 400 });

  // une seule fois par élément
  const { error: dup } = await sb.from("push_log").insert({ kind: type, ref: String(id) });
  if (dup) return new Response("already sent");

  let users: string[] = [], payload: Record<string, string> = {};

  if (type === "message") {
    const { data: m } = await sb.from("messages").select("*").eq("id", id).maybeSingle();
    if (!m || !fresh(m.created_at)) return new Response("skip");
    const ch: string = m.channel;
    const name = ch.startsWith("grp:") ? `Parents ${ch.slice(4)}` : ({ club: "Questions au club", all: "Annonces du club", covoit: "Covoiturage" } as Record<string, string>)[ch] ?? "Messagerie";
    const parents = await parentsOfGroups(ch.startsWith("grp:") ? [ch.slice(4)] : null);
    users = [...new Set([...parents, ...(await coaches())])].filter((u) => u !== m.author_id);
    payload = { title: `💬 ${name}`, body: cut(`${m.author_name} : ${m.body}`, 140), url: "#messages", tag: `msg-${ch}` };
  } else if (type === "event") {
    const { data: e } = await sb.from("events").select("*").eq("id", id).maybeSingle();
    if (!e || !fresh(e.created_at)) return new Response("skip");
    const groups: string[] | null = !e.groups || e.groups.includes("all") ? null : e.groups;
    users = (await parentsOfGroups(groups)).filter((u) => u !== e.created_by);
    const d = new Date(e.date + "T12:00:00").toLocaleDateString("fr-FR", { weekday: "long", day: "numeric", month: "long" });
    payload = { title: e.kind === "compet" ? "🏅 Nouvelle compétition" : "📅 Nouvel événement au club", body: cut(`${e.title} · ${d}`, 140), url: "#agenda", tag: `ev-${e.id}` };
  } else if (type === "selection") {
    const [kidId, evId] = String(id).split("|");
    const { data: k } = await sb.from("kids").select("name, parent_id").eq("id", kidId).maybeSingle();
    const { data: e } = await sb.from("events").select("title").eq("id", evId).maybeSingle();
    if (!k || !e) return new Response("skip");
    const ok = await approvedParents();
    users = ok.has(k.parent_id) ? [k.parent_id] : [];
    payload = { title: `🏅 ${k.name} est sélectionnée !`, body: cut(`${e.title} : confirme sa présence dans l’appli.`, 140), url: "#agenda", tag: `sel-${evId}` };
  } else return new Response("unknown type", { status: 400 });

  if (!users.length) return new Response("nobody");
  const { data: subs } = await sb.from("push_subs").select("*").in("user_id", users);
  let sent = 0;
  await Promise.all((subs ?? []).map(async (s) => {
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify(payload), { TTL: 86400 });
      sent++;
    } catch (err) {
      const code = (err as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) await sb.from("push_subs").delete().eq("endpoint", s.endpoint);
    }
  }));
  return new Response(JSON.stringify({ sent }), { headers: { "Content-Type": "application/json" } });
});
