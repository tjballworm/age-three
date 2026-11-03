defmodule Age3.Repo.Migrations.TitlesMedals do
  # Ranks, titles and medals (Age3.Titles). Players store rank and title ids, so the old "Civilian" title becomes
  # "civilian". medals counts each medal the player holds, e.g. {"cross": 3}; a battle report keeps the medals
  # that battle dropped.
  use Ecto.Migration

  def up do
    alter table(:players) do
      add :military_rank, :text, null: false, default: "civilian"
      add :medals, :map, null: false, default: %{}
      modify :title, :text, null: false, default: "civilian"
    end

    execute "UPDATE players SET title = lower(title)"

    alter table(:battle_reports) do
      add :medals, :map, null: false, default: %{}
    end
  end

  def down do
    alter table(:battle_reports) do
      remove :medals
    end

    execute "UPDATE players SET title = initcap(title)"

    alter table(:players) do
      modify :title, :text, null: false, default: "Civilian"
      remove :medals
      remove :military_rank
    end
  end
end
