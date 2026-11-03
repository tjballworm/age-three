defmodule Age3.Repo.Migrations.Pvp do
  # Attacking and capturing other players' cities (plans/capture-loyalty-plan.md).
  #
  # tasks.target_city_id: the player city a march is heading for (nil for NPCs and for the way home), so a city can
  # find the attacks coming at it. cities.gate_open: the Rally Spot's "open gate to fight" (closed keeps the troops
  # out of battles); cities.defender_hero_id: the hero who leads the defence, chosen apart from the mayor.
  # battle_reports.side: "attack" or "defence" (each player gets their own report of a battle); loyalty: the city's
  # loyalty before and after, and whether it was captured.
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :target_city_id, :binary_id
    end

    create index(:tasks, [:target_city_id])

    alter table(:cities) do
      add :gate_open, :boolean, null: false, default: false
      add :defender_hero_id, :binary_id
    end

    alter table(:battle_reports) do
      add :side, :text, null: false, default: "attack"
      add :loyalty, :map
    end
  end
end
