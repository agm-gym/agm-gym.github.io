-- =====================================================================
--  AGM Gym : les coachs sont reconnus par leur adresse e-mail (remplace le code coach)
-- =====================================================================
create table public.coach_emails (
  email     text primary key check (email = lower(trim(email)) and email like '%_@_%._%'),
  added_by  uuid default auth.uid(),
  added_at  timestamptz default now()
);
alter table public.coach_emails enable row level security;
create policy "coachs lus"     on public.coach_emails for select using (public.is_coach());
create policy "coach ajouté"   on public.coach_emails for insert with check (public.is_coach());
create policy "coach retiré"   on public.coach_emails for delete using (public.is_coach());

-- quand une adresse est ajoutée ou retirée, le rôle du compte suit tout de suite
create function public.coach_email_changed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update profiles set role = 'coach' where lower(email) = new.email;
    return new;
  else
    update profiles set role = 'parent' where lower(email) = old.email;
    return old;
  end if;
end $$;
create trigger coach_email_added   after insert on public.coach_emails for each row execute function public.coach_email_changed();
create trigger coach_email_removed after delete on public.coach_emails for each row execute function public.coach_email_changed();

-- un compte créé avec une adresse de la liste est coach dès sa première connexion
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, new.email,
          case when exists (select 1 from public.coach_emails where email = lower(new.email)) then 'coach' else 'parent' end);
  return new;
end $$;

-- l'ancien code coach n'est plus utilisable
revoke execute on function public.claim_coach(text) from authenticated;

-- premier coach : à remplacer par l'adresse de la personne qui gère l'appli
-- insert into public.coach_emails (email) values ('prenom.nom@exemple.fr');
