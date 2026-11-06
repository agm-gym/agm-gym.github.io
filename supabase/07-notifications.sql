-- =====================================================================
--  AGM Gym : notifications (messages, événements, sélections)
-- =====================================================================
create extension if not exists pg_net;

-- les téléphones abonnés aux notifications
create table public.push_subs (
  endpoint    text primary key,
  user_id     uuid not null references auth.users on delete cascade default auth.uid(),
  p256dh      text not null,
  auth        text not null,
  created_at  timestamptz default now()
);
alter table public.push_subs enable row level security;
create policy "abonnement lu"      on public.push_subs for select using (user_id = auth.uid());
create policy "abonnement ajouté"  on public.push_subs for insert with check (user_id = auth.uid());
create policy "abonnement modifié" on public.push_subs for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "abonnement retiré"  on public.push_subs for delete using (user_id = auth.uid());

-- chaque notification n'est envoyée qu'une fois
create table public.push_log (
  kind  text not null,
  ref   text not null,
  sent_at timestamptz default now(),
  primary key (kind, ref)
);
alter table public.push_log enable row level security;   -- réservé au serveur

-- appel de la fonction d'envoi
create function public.notify_push(kind text, ref text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url     := 'https://jvvvqzithtdqwuuccpqw.supabase.co/functions/v1/send-push',
    body    := jsonb_build_object('type', kind, 'id', ref),
    headers := '{"Content-Type":"application/json"}'::jsonb);
exception when others then null;   -- une notification ratée ne bloque jamais l'appli
end $$;

create function public.trg_push_message() returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.notify_push('message', new.id::text); return new; end $$;
create trigger push_message after insert on public.messages for each row execute function public.trg_push_message();

create function public.trg_push_event() returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.notify_push('event', new.id); return new; end $$;
create trigger push_event after insert on public.events for each row execute function public.trg_push_event();

create function public.trg_push_selection() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.selected and (tg_op = 'INSERT' or not old.selected) then
    perform public.notify_push('selection', new.kid_id::text || '|' || new.event_id);
  end if;
  return new;
end $$;
create trigger push_selection after insert or update on public.selections for each row execute function public.trg_push_selection();
