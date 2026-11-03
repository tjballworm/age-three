defmodule Age3.Repo.Migrations.Marches do
  # Marches run as tasks of kind "march" (so the task runner finishes them like builds): one task to get there,
  # then a new one for the way back. tasks.data holds what the march carries: troops, hero, target, loot, phase.
  #
  # npc_states remembers an NPC city that has been attacked: what was left of its garrison, fortifications and
  # resources, and when. It refills from there a little every second (Age3.Npc); an NPC with no row is full.
  #
  # battle_reports are each player's battles, with the whole engine result for the Reports window.
  # players.instant_march is a tester cheat: that player's marches take a second each way.
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :data, :map
    end

    create table(:npc_states, primary_key: false) do
      add :x, :integer, primary_key: true
      add :y, :integer, primary_key: true
      add :level, :integer, null: false
      add :troops, :map, null: false
      add :forts, :map, null: false
      add :resources, :map, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create table(:battle_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :player_id, references(:players, type: :binary_id, on_delete: :delete_all), null: false
      add :city_id, :binary_id
      add :title, :string, null: false
      add :x, :integer, null: false
      add :y, :integer, null: false
      add :won, :boolean, null: false
      add :loot, :map, null: false, default: %{}
      add :hero, :map
      add :result, :map, null: false
      add :read, :boolean, null: false, default: false
      add :fought_at, :utc_datetime_usec, null: false
    end

    create index(:battle_reports, [:player_id, :fought_at])

    alter table(:players) do
      add :instant_march, :boolean, null: false, default: false
    end
  end
end
