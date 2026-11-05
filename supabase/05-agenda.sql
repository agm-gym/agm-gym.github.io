-- =====================================================================
--  AGM Gym : agenda partagé (événements publiés par les coachs)
-- =====================================================================
create table public.events (
  id          text primary key default gen_random_uuid()::text,
  kind        text not null check (kind in ('fort','stage','compet')),
  title       text not null check (char_length(title) between 1 and 120),
  body        text not null default '' check (char_length(body) <= 1500),
  date        date not null,
  end_date    date check (end_date is null or end_date >= date),
  time_label  text not null default '' check (char_length(time_label) <= 40),
  groups      text[] not null default '{all}',      -- '{all}' = tous les groupes
  cap         int check (cap is null or cap > 0),   -- vide = pas de limite de places
  price       text not null default '' check (char_length(price) <= 60),
  guests      boolean not null default false,       -- les familles peuvent venir à plusieurs
  created_by  uuid default auth.uid(),
  created_at  timestamptz default now()
);
alter table public.events enable row level security;
create policy "agenda lu"          on public.events for select using (auth.uid() is not null);
create policy "événement ajouté"   on public.events for insert with check (public.is_coach());
create policy "événement modifié"  on public.events for update using (public.is_coach()) with check (public.is_coach());
create policy "événement supprimé" on public.events for delete using (public.is_coach());

-- nombre d'inscrits par événement (sans révéler qui)
create function public.event_counts() returns table (event_id text, taken bigint)
language sql stable security definer set search_path = public as $$
  select event_id, count(*) from public.event_regs where status = 'yes' group by event_id;
$$;
revoke all on function public.event_counts() from public, anon;
grant execute on function public.event_counts() to authenticated;
