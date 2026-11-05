-- =====================================================================
--  AGM Gym : base de données Supabase
--  À coller en entier dans Supabase > SQL Editor > New query > Run
-- =====================================================================

-- 1. Profils (un par compte : parent ou coach)
create table public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  email       text,
  display_name text,
  role        text not null default 'parent' check (role in ('parent','coach')),
  created_at  timestamptz default now()
);

-- crée le profil automatiquement à la première connexion
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- vrai si la personne connectée est coach
create function public.is_coach() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'coach');
$$;

-- 2. Enfants (rattachés à un parent)
create table public.kids (
  id         uuid primary key default gen_random_uuid(),
  parent_id  uuid not null references public.profiles on delete cascade default auth.uid(),
  name       text not null,
  grp        text not null,            -- 'GAF 1' … 'GAF 3', 'B1' … 'B6'
  created_at timestamptz default now()
);

-- vrai si l'enfant appartient à la personne connectée
create function public.is_my_kid(k uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.kids where id = k and parent_id = auth.uid());
$$;

-- 3. Présences aux cours (réponse du parent)
create table public.attendance (
  kid_id      uuid references public.kids on delete cascade,
  session_key text,                    -- identifiant du cours (groupe + date)
  status      text check (status in ('yes','no')),
  reason      text,
  updated_at  timestamptz default now(),
  primary key (kid_id, session_key)
);

-- 4. Inscriptions aux événements / confirmations de compétition (parent)
create table public.event_regs (
  kid_id     uuid references public.kids on delete cascade,
  event_id   text,
  status     text not null default 'yes' check (status in ('yes','no')),
  guests     int not null default 0,     -- invités (fêtes, gala)
  updated_at timestamptz default now(),
  primary key (kid_id, event_id)
);

-- 5. Sélection en compétition (coachs)
create table public.selections (
  kid_id    uuid references public.kids on delete cascade,
  event_id  text,
  selected  boolean not null default true,
  primary key (kid_id, event_id)
);

-- 6. Appel (coachs)
create table public.roll_call (
  kid_id      uuid references public.kids on delete cascade,
  session_key text,
  present     boolean not null,
  primary key (kid_id, session_key)
);
create table public.roll_call_done (
  grp         text,
  session_key text,
  done_at     timestamptz default now(),
  primary key (grp, session_key)
);

-- 7. Skills validés (coachs)
create table public.badges (
  kid_id    uuid references public.kids on delete cascade,
  skill_id  text,
  given_at  timestamptz default now(),
  primary key (kid_id, skill_id)
);

-- 8. Documents remis (parent)
create table public.docs_sent (
  kid_id   uuid references public.kids on delete cascade,
  doc_id   text,
  sent_at  timestamptz default now(),
  primary key (kid_id, doc_id)
);

-- 9. Programme de cours (coachs uniquement)
create table public.plans (
  grp         text,
  session_key text,
  content     jsonb,
  primary key (grp, session_key)
);

-- =====================================================================
--  Sécurité : chaque parent ne voit que ses enfants, les coachs voient tout
-- =====================================================================
alter table public.profiles       enable row level security;
alter table public.kids           enable row level security;
alter table public.attendance     enable row level security;
alter table public.event_regs     enable row level security;
alter table public.selections     enable row level security;
alter table public.roll_call      enable row level security;
alter table public.roll_call_done enable row level security;
alter table public.badges         enable row level security;
alter table public.docs_sent      enable row level security;
alter table public.plans          enable row level security;

-- profils : chacun lit le sien, les coachs lisent tout ; on modifie seulement son nom
create policy "profil lu"     on public.profiles for select using (id = auth.uid() or public.is_coach());
create policy "profil modifié" on public.profiles for update using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));

-- enfants
create policy "enfants lus"     on public.kids for select using (parent_id = auth.uid() or public.is_coach());
create policy "enfant ajouté"   on public.kids for insert with check (parent_id = auth.uid());
create policy "enfant modifié"  on public.kids for update using (parent_id = auth.uid()) with check (parent_id = auth.uid());
create policy "enfant supprimé" on public.kids for delete using (parent_id = auth.uid());

-- données écrites par le parent, lues par les coachs
create policy "présences lues"  on public.attendance for select using (public.is_my_kid(kid_id) or public.is_coach());
create policy "présences parent" on public.attendance for all using (public.is_my_kid(kid_id)) with check (public.is_my_kid(kid_id));
create policy "inscriptions lues"  on public.event_regs for select using (public.is_my_kid(kid_id) or public.is_coach());
create policy "inscriptions parent" on public.event_regs for all using (public.is_my_kid(kid_id)) with check (public.is_my_kid(kid_id));
create policy "docs lus"   on public.docs_sent for select using (public.is_my_kid(kid_id) or public.is_coach());
create policy "docs parent" on public.docs_sent for all using (public.is_my_kid(kid_id)) with check (public.is_my_kid(kid_id));

-- données écrites par les coachs, lues par le parent concerné
create policy "sélection lue"   on public.selections for select using (public.is_my_kid(kid_id) or public.is_coach());
create policy "sélection coach" on public.selections for all using (public.is_coach()) with check (public.is_coach());
create policy "skills lus"   on public.badges for select using (public.is_my_kid(kid_id) or public.is_coach());
create policy "skills coach" on public.badges for all using (public.is_coach()) with check (public.is_coach());

-- données réservées aux coachs
create policy "appel coach"      on public.roll_call      for all using (public.is_coach()) with check (public.is_coach());
create policy "appel fait coach" on public.roll_call_done for all using (public.is_coach()) with check (public.is_coach());
create policy "programme coach"  on public.plans          for all using (public.is_coach()) with check (public.is_coach());
