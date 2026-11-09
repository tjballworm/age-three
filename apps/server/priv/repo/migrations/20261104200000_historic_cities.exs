defmodule Age3.Repo.Migrations.HistoricCities do
  # Capturing historic cities and their policies (design/historic-cities-policies.md in the project files).
  #
  # npc_states.loyalty: a historic city's loyalty as of updated_at (each won attack takes 3; at 0 a win captures
  # it). cities.historic_level: 12-18 for a captured historic city (nil for every other city); its Rally Spot
  # sends more and it can impose policies. cities.policies_used / policies_day: policies imposed on that day
  # (days since the epoch, UTC). battle_reports.policy: what a policy took, for a policy report (they have no
  # battle, so result can be empty now).
  use Ecto.Migration

  def change do
    alter table(:npc_states) do
      add :loyalty, :integer, null: false, default: 100
    end

    alter table(:cities) do
      add :historic_level, :integer
      add :policies_used, :integer, null: false, default: 0
      add :policies_day, :integer, null: false, default: 0
    end

    alter table(:battle_reports) do
      add :policy, :map
      modify :result, :map, null: true, from: {:map, null: false}
    end
  end
end
