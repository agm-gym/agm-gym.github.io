-- =====================================================================
--  AGM Gym : devenir coach avec le code du club (à exécuter après 02-messagerie.sql)
--  Le code lui-même n'est PAS dans ce fichier public : il est saisi directement dans Supabase.
-- =====================================================================
create table public.club_settings (
  id          int primary key default 1 check (id = 1),
  coach_code  text not null
);
alter table public.club_settings enable row level security;   -- aucune règle : personne ne peut le lire depuis l'appli

-- garde une trace des essais pour limiter les tentatives au hasard
create table public.coach_attempts (
  user_id uuid references auth.users on delete cascade,
  at      timestamptz default now()
);
alter table public.coach_attempts enable row level security;

create function public.claim_coach(code text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return false; end if;
  if (select count(*) from coach_attempts where user_id = auth.uid() and at > now() - interval '1 hour') >= 5 then
    raise exception 'Trop d''essais, réessaie dans une heure';
  end if;
  insert into coach_attempts (user_id) values (auth.uid());
  if exists (select 1 from club_settings where id = 1 and coach_code = upper(trim(code))) then
    update profiles set role = 'coach' where id = auth.uid();
    return true;
  end if;
  return false;
end $$;
revoke all on function public.claim_coach(text) from public, anon;
grant execute on function public.claim_coach(text) to authenticated;

-- À faire une fois, dans Supabase uniquement (remplacer par le code choisi) :
--   insert into public.club_settings (id, coach_code) values (1, 'AGM-XXXXXX')
--     on conflict (id) do update set coach_code = excluded.coach_code;
