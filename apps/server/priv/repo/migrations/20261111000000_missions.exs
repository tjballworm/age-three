defmodule Age3.Repo.Migrations.Missions do
  # More march missions: scouting, transports, reinforcements, founding cities and taking valleys.
  #
  # battle_reports.scout: what a scout saw (Age3.Scout.report/2), for a scout report (side "scout" for the
  # sender, "scouted" for the city scouted); it has no battle. Other mission reports (a transport delivered, a
  # city founded, a valley lost) use the same table with no result either.
  #
  # cities.allow_garrison: allies may station reinforcements in the city (its Embassy level = how many waves).
  #
  # valleys: the valleys players' cities hold. A row per held valley tile; a free valley has none (its garrison,
  # once attacked, lives in npc_states like an NPC's). level and terrain are copied from the generated map.
  use Ecto.Migration

  def change do
    alter table(:battle_reports) do
      add :scout, :map
      add :kind, :string, null: false, default: "battle"
    end

    # the Embassy's "allow allies to garrison" box
    alter table(:cities) do
      add :allow_garrison, :boolean, null: false, default: false
    end

    create table(:valleys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :city_id, references(:cities, type: :binary_id, on_delete: :delete_all), null: false
      add :x, :integer, null: false
      add :y, :integer, null: false
      add :level, :integer, null: false
      add :terrain, :string, null: false
      add :taken_at, :utc_datetime_usec, null: false
    end

    create unique_index(:valleys, [:x, :y])
    create index(:valleys, [:city_id])
  end
end
