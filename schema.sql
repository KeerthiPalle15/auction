-- Supabase Schema for Cricket Tournament App

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- USERS TABLE
CREATE TABLE public.users (
  id UUID references auth.users not null primary key,
  email TEXT not null,
  role TEXT not null check (role in ('admin', 'captain', 'viewer')),
  team_id UUID, -- nullable, set if role=captain
  created_at TIMESTAMPTZ default now()
);

-- TEAMS TABLE
CREATE TABLE public.teams (
  id UUID default uuid_generate_v4() primary key,
  name TEXT not null,
  purse INTEGER not null default 0,
  created_at TIMESTAMPTZ default now()
);

-- alter users to add team_id fk
ALTER TABLE public.users ADD CONSTRAINT fk_team FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE SET NULL;

-- PLAYERS TABLE
CREATE TABLE public.players (
  id UUID default uuid_generate_v4() primary key,
  name TEXT not null,
  role TEXT not null check (role in ('batsman', 'bowler', 'all-rounder', 'wicketkeeper')),
  base_price INTEGER not null,
  created_at TIMESTAMPTZ default now()
);

-- AUCTIONS TABLE
-- To track the live status and sold players.
CREATE TABLE public.auctions (
  id UUID default uuid_generate_v4() primary key,
  player_id UUID references public.players(id) on delete cascade not null,
  team_id UUID references public.teams(id) on delete set null,
  sold_price INTEGER,
  status TEXT not null check (status in ('upcoming', 'live', 'sold', 'unsold')) default 'upcoming',
  current_bid INTEGER default 0,
  current_bid_team_id UUID references public.teams(id) on delete set null,
  created_at TIMESTAMPTZ default now()
);

-- MATCHES TABLE
CREATE TABLE public.matches (
  id UUID default uuid_generate_v4() primary key,
  team1_id UUID references public.teams(id) on delete cascade not null,
  team2_id UUID references public.teams(id) on delete cascade not null,
  status TEXT not null check (status in ('upcoming', 'live', 'completed')) default 'upcoming',
  toss_winner_id UUID references public.teams(id) on delete set null,
  toss_decision TEXT check (toss_decision in ('bat', 'bowl')),
  created_at TIMESTAMPTZ default now()
);

-- MATCH EVENTS (BALL BY BALL)
CREATE TABLE public.match_events (
  id UUID default uuid_generate_v4() primary key,
  match_id UUID references public.matches(id) on delete cascade not null,
  innings INTEGER not null check (innings in (1, 2)),
  over_number INTEGER not null,
  ball_number INTEGER not null, -- usually 1 to 6
  runs INTEGER not null default 0,
  extra_runs INTEGER not null default 0,
  extra_type TEXT check (extra_type in ('wide', 'no-ball', 'bye', 'leg-bye')),
  wicket_type TEXT check (wicket_type in ('bowled', 'caught', 'run-out', 'run-out-striker', 'run-out-nonstriker', 'lbw', 'stumped', 'hit-wicket')),
  batsman_id UUID references public.players(id) on delete set null,
  bowler_id UUID references public.players(id) on delete set null,
  is_undo BOOLEAN default false,
  created_at TIMESTAMPTZ default now()
);

-- RLS & Realtime Setup
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auctions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;

-- Allow read access to everyone for all these tables
CREATE POLICY "Public profiles are viewable by everyone." on public.users for select using (true);
CREATE POLICY "Teams viewable by everyone." on public.teams for select using (true);
CREATE POLICY "Players viewable by everyone." on public.players for select using (true);
CREATE POLICY "Auctions viewable by everyone." on public.auctions for select using (true);
CREATE POLICY "Matches viewable by everyone." on public.matches for select using (true);
CREATE POLICY "Match events viewable by everyone." on public.match_events for select using (true);

-- Allow authenticated users to insert/update based on roles
-- Note: Simplified for the demo, normally we'd check JWT claims for admin/captain role
CREATE POLICY "Allow all authenticated users to insert/update (for demo apps)" on public.users for all using (auth.role() = 'authenticated');
CREATE POLICY "Allow all authenticated users to insert/update teams" on public.teams for all using (auth.role() = 'authenticated');
CREATE POLICY "Allow all authenticated users to insert/update players" on public.players for all using (auth.role() = 'authenticated');
CREATE POLICY "Allow all authenticated users to insert/update auctions" on public.auctions for all using (auth.role() = 'authenticated');
CREATE POLICY "Allow all authenticated users to insert/update matches" on public.matches for all using (auth.role() = 'authenticated');
CREATE POLICY "Allow all authenticated users to insert/update match_events" on public.match_events for all using (auth.role() = 'authenticated');

-- Enable realtime subscriptions for tables
alter publication supabase_realtime add table public.auctions;
alter publication supabase_realtime add table public.matches;
alter publication supabase_realtime add table public.match_events;
alter publication supabase_realtime add table public.teams;
