-- =====================================================================
--  AGM Gym : compétitions par équipe (les parents voient les prénoms de l'équipe)
-- =====================================================================
alter table public.events add column if not exists team boolean not null default false;

-- prénoms des gymnastes sélectionnées, visibles seulement par les coachs
-- et par les parents dont un enfant fait partie de l'équipe
create function public.team_members(ev text) returns table (name text, grp text)
language sql stable security definer set search_path = public as $$
  select k.name, k.grp
  from public.selections s
  join public.kids k on k.id = s.kid_id
  join public.events e on e.id = s.event_id
  where s.event_id = ev and s.selected and e.team
    and (public.is_coach() or exists (
          select 1 from public.selections s2 join public.kids k2 on k2.id = s2.kid_id
          where s2.event_id = ev and s2.selected and k2.parent_id = auth.uid()))
  order by k.name;
$$;
revoke all on function public.team_members(text) from public, anon;
grant execute on function public.team_members(text) to authenticated;
