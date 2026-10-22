-- Players, their cities, the buildings in each town, and timed tasks (builds, training, research, marches).

create table players (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  title text not null default 'Civilian',
  alliance text,
  prestige integer not null default 0,
  honor integer not null default 0,
  created_at timestamptz not null default now()
);

create table cities (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references players (id) on delete cascade,
  name text not null,
  x integer not null,
  y integer not null,
  level integer not null default 1,
  loyalty integer not null default 100,
  tax_rate integer not null default 10,
  -- Record<ResourceType, ResourceStock>, as of synced_at
  resources jsonb not null,
  -- Population
  population jsonb not null,
  synced_at timestamptz not null default now(),
  unique (x, y)
);
create index cities_player on cities (player_id);

create table buildings (
  city_id uuid not null references cities (id) on delete cascade,
  -- '0'..'31', 'townhall' or 'walls'
  slot text not null,
  type text not null,
  level integer not null check (level between 1 and 10),
  upgrading boolean not null default false,
  primary key (city_id, slot)
);

create table tasks (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references cities (id) on delete cascade,
  kind text not null,
  label text not null,
  started_at timestamptz not null,
  ends_at timestamptz not null
);
create index tasks_due on tasks (ends_at);
