defmodule Age3.Repo.Migrations.Heroes do
  # Heroes belong to a city (they live in its Feasting Hall). Leadership is their level, so it isn't stored.
  # status is "idle", "mayor" or "marching"; a city has at most one mayor. cities.inn holds the heroes its Inn
  # offers for hire: {"refreshAt": ms, "level": Inn level they were rolled for, "offers": [...]}.
  use Ecto.Migration

  def change do
    create table(:heroes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :city_id, references(:cities, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :level, :integer, null: false, default: 1
      add :exp, :integer, null: false, default: 0
      # stat points from levelling up, not spent yet
      add :points, :integer, null: false, default: 0
      add :politics, :integer, null: false
      add :attack, :integer, null: false
      add :intelligence, :integer, null: false
      add :status, :string, null: false, default: "idle"
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:heroes, [:city_id])
    create unique_index(:heroes, [:city_id], where: "status = 'mayor'", name: :heroes_one_mayor)

    alter table(:cities) do
      add :inn, :map, null: false, default: %{}
    end
  end
end
