-- =====================================================================
--  AGM Gym : messagerie (à exécuter après schema.sql)
-- =====================================================================
create table public.messages (
  id          uuid primary key default gen_random_uuid(),
  channel     text not null check (channel in ('club','all','covoit') or channel like 'grp:%'),
  author_id   uuid not null references public.profiles on delete cascade default auth.uid(),
  author_name text not null check (char_length(author_name) between 1 and 80),
  is_coach    boolean not null default false,
  body        text not null check (char_length(body) between 1 and 2000),
  created_at  timestamptz not null default now()
);
create index messages_channel_created on public.messages (channel, created_at desc);

-- l'auteur, le badge « Club » et l'heure sont fixés par le serveur (impossible de se faire passer pour un coach)
create function public.msg_defaults() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.author_id  := auth.uid();
  new.is_coach   := public.is_coach();
  new.created_at := now();
  return new;
end $$;
create trigger msg_defaults before insert on public.messages
  for each row execute function public.msg_defaults();

-- qui peut lire une discussion : les coachs partout ; les parents dans les discussions communes
-- et dans celles des groupes de leurs enfants
create function public.can_read_channel(ch text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_coach()
      or ch in ('club','all','covoit')
      or exists (select 1 from public.kids where parent_id = auth.uid() and 'grp:' || grp = ch);
$$;

alter table public.messages enable row level security;
create policy "messages lus"     on public.messages for select using (public.can_read_channel(channel));
create policy "message envoyé"   on public.messages for insert
  with check (author_id = auth.uid() and public.can_read_channel(channel) and (channel <> 'all' or public.is_coach()));
create policy "message supprimé" on public.messages for delete using (author_id = auth.uid() or public.is_coach());

-- colonne ajoutée après la première version (sans effet si elle existe déjà)
alter table public.event_regs add column if not exists guests int not null default 0;
