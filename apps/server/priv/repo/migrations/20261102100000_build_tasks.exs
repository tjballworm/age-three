defmodule Age3.Repo.Migrations.BuildTasks do
  # Construction runs as a row in tasks: what is being built where, to which level, and what it cost (refunded on
  # cancel). Whether a building is upgrading now comes from its task, so buildings.upgrading goes.
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      # '0'..'31', 'townhall', 'walls' or 'f0'..'f12'
      add :slot, :text
      add :target_type, :text
      add :target_level, :integer
      # Record<ResourceType, number>
      add :cost, :map
    end

    # one construction at a time per city, enforced by the database itself
    create unique_index(:tasks, [:city_id], where: "kind = 'build'", name: :tasks_one_build)

    alter table(:buildings) do
      remove :upgrading, :boolean, default: false, null: false
    end
  end
end
