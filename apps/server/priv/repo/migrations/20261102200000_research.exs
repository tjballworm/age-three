defmodule Age3.Repo.Migrations.Research do
  # Research levels belong to the player, shared by all their cities: {"agriculture": 2, ...}. Existing players
  # start with none. A research runs as a row in tasks (kind 'research', target_type = the tech, target_level),
  # one per city's Academy at a time.
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :research, :map, null: false, default: %{}
    end

    create unique_index(:tasks, [:city_id], where: "kind = 'research'", name: :tasks_one_research)
  end
end
