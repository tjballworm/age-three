defmodule Age3.Repo.Migrations.Init do
  # Players, their cities, the buildings in each town, and timed tasks (builds, training, research, marches).
  #
  # The same SQL as the Go server's 001_init.sql, with "if not exists" added: the database on Neon already has
  # these tables from the Go server, so there this only records the migration as done. Later migrations can
  # use Ecto's helpers (create table(...), add ..., alter ...) instead of SQL.
  use Ecto.Migration

  def up do
    execute """
    create table if not exists players (
      id uuid primary key default gen_random_uuid(),
      name text not null unique,
      title text not null default 'Civilian',
      alliance text,
      prestige integer not null default 0,
      honor integer not null default 0,
      created_at timestamptz not null default now()
    )
    """

    execute """
    create table if not exists cities (
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
    )
    """

    execute "create index if not exists cities_player on cities (player_id)"

    execute """
    create table if not exists buildings (
      city_id uuid not null references cities (id) on delete cascade,
      -- '0'..'31', 'townhall' or 'walls'
      slot text not null,
      type text not null,
      level integer not null check (level between 1 and 10),
      upgrading boolean not null default false,
      primary key (city_id, slot)
    )
    """

    execute """
    create table if not exists tasks (
      id uuid primary key default gen_random_uuid(),
      city_id uuid not null references cities (id) on delete cascade,
      kind text not null,
      label text not null,
      started_at timestamptz not null,
      ends_at timestamptz not null
    )
    """

    execute "create index if not exists tasks_due on tasks (ends_at)"
  end

  def down do
    execute "drop table if exists tasks, buildings, cities, players"
  end
end
