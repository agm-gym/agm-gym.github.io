-- =====================================================================
--  AGM Gym : un nouveau compte parent doit être validé par un coach
-- =====================================================================
alter table public.profiles add column if not exists approved boolean not null default false;
alter table public.profiles add column if not exists rejected boolean not null default false;

-- les comptes déjà là (coachs et familles de test) restent actifs
update public.profiles set approved = true;

-- vrai si la personne connectée est coach ou parent validé
create function public.is_approved() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and (role = 'coach' or approved));
$$;

-- un compte créé avec une adresse de coach est validé d'office
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare c boolean := exists (select 1 from public.coach_emails where email = lower(new.email));
begin
  insert into public.profiles (id, email, role, approved)
  values (new.id, new.email, case when c then 'coach' else 'parent' end, c);
  return new;
end $$;

create or replace function public.coach_email_changed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update profiles set role = 'coach', approved = true, rejected = false where lower(email) = new.email;
    return new;
  else
    update profiles set role = 'parent' where lower(email) = old.email;
    return old;
  end if;
end $$;

-- un parent ne peut modifier que son nom : ni son rôle, ni sa validation
drop policy if exists "profil modifié" on public.profiles;
create policy "profil modifié" on public.profiles for update using (id = auth.uid())
  with check (id = auth.uid()
    and role     = (select p.role     from public.profiles p where p.id = auth.uid())
    and approved = (select p.approved from public.profiles p where p.id = auth.uid())
    and rejected = (select p.rejected from public.profiles p where p.id = auth.uid()));

-- validation ou refus par un coach
create function public.review_family(parent uuid, ok boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_coach() then raise exception 'Réservé aux coachs'; end if;
  update profiles set approved = ok, rejected = not ok where id = parent and role = 'parent';
end $$;
revoke all on function public.review_family(uuid, boolean) from public, anon;
grant execute on function public.review_family(uuid, boolean) to authenticated;

-- les messages et l'agenda ne sont visibles qu'une fois validé
create or replace function public.can_read_channel(ch text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_coach()
      or (public.is_approved() and (
            ch in ('club','all','covoit')
         or exists (select 1 from public.kids where parent_id = auth.uid() and 'grp:' || grp = ch)));
$$;
drop policy if exists "agenda lu" on public.events;
create policy "agenda lu" on public.events for select using (public.is_approved());
