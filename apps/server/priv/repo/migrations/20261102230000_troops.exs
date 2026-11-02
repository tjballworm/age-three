defmodule Age3.Repo.Migrations.Troops do
  # Trained troops belong to a city: {"warrior": 100, ...}. Existing cities start with none. Training runs as rows
  # in tasks (kind 'train', slot = the Barracks, target_type = the troop, target_level = how many), several per
  # Barracks, one after another, so there is no unique index for them.
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :troops, :map, null: false, default: %{}
    end
  end
end
