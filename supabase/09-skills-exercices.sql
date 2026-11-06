-- =====================================================================
--  AGM Gym : skills et exercices personnalisables par les coachs
-- =====================================================================
create table public.club_skills (
  id        text primary key default gen_random_uuid()::text,
  k         text not null default 'sol',            -- agrès : sol, poutre, barres, saut, echauf, jeu, etire
  name      text not null check (char_length(name) between 1 and 60),
  groups    text[] not null default '{all}',
  position  int not null default 100,
  created_at timestamptz default now()
);
create table public.club_exercises (
  id        text primary key default gen_random_uuid()::text,
  k         text not null default 'sol',
  name      text not null check (char_length(name) between 1 and 60),
  minutes   int not null default 10 check (minutes between 1 and 120),
  created_at timestamptz default now()
);
alter table public.club_skills    enable row level security;
alter table public.club_exercises enable row level security;
create policy "skills lus"        on public.club_skills    for select using (public.is_approved());
create policy "skills gérés"      on public.club_skills    for all    using (public.is_coach()) with check (public.is_coach());
create policy "exercices lus"     on public.club_exercises for select using (public.is_coach());
create policy "exercices gérés"   on public.club_exercises for all    using (public.is_coach()) with check (public.is_coach());

-- liste de départ (celle de l'appli aujourd'hui)
insert into public.club_skills (id, k, name, position) values
  ('rav', 'sol', 'Roulade avant', 0),
  ('rar', 'sol', 'Roulade arrière', 10),
  ('chd', 'sol', 'Chandelle', 20),
  ('pont', 'sol', 'Pont', 30),
  ('roue', 'sol', 'Roue', 40),
  ('atr', 'sol', 'Poirier', 50),
  ('eqp', 'poutre', 'Équilibre poutre', 60),
  ('dtp', 'poutre', 'Demi-tour poutre', 70),
  ('apb', 'barres', 'Appui barres', 80),
  ('bal', 'barres', 'Balancés', 90),
  ('sext', 'saut', 'Saut extension', 100),
  ('sgr', 'saut', 'Saut groupé', 110);
insert into public.club_exercises (k, name, minutes) values
  ('echauf', 'Course autour du praticable', 5),
  ('echauf', 'Sauts de grenouille', 5),
  ('echauf', 'Corde à sauter', 5),
  ('echauf', 'Gainage planche', 5),
  ('echauf', 'Parcours de motricité', 10),
  ('sol', 'Roulade avant', 10),
  ('sol', 'Roulade arrière', 10),
  ('sol', 'Roue', 10),
  ('sol', 'Poirier contre le mur', 10),
  ('sol', 'Pont', 5),
  ('sol', 'Chandelle', 5),
  ('poutre', 'Marche sur pointes', 10),
  ('poutre', 'Demi-tour', 10),
  ('poutre', 'Saut extension', 10),
  ('poutre', 'Équilibre arabesque', 5),
  ('poutre', 'Pas chassés', 10),
  ('barres', 'Suspension', 5),
  ('barres', 'Balancés', 10),
  ('barres', 'Appui tendu', 10),
  ('barres', 'Tour d’appui', 10),
  ('saut', 'Course d’élan', 10),
  ('saut', 'Appel sur le tremplin', 10),
  ('saut', 'Saut groupé', 10),
  ('saut', 'Réception stable', 5),
  ('jeu', 'Les statues', 10),
  ('jeu', 'Chat perché gym', 10),
  ('jeu', 'Relais en équipes', 10),
  ('jeu', 'Jacques a dit', 5),
  ('etire', 'Grand écart', 5),
  ('etire', 'Pont', 5),
  ('etire', 'Papillon', 5),
  ('etire', 'Respiration', 5);
