defmodule Age3.Repo.Migrations.TownHallActions do
  # Levies (Age3.Levy): levy_at is the city's last levy, for the 15 minute cooldown.
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :levy_at, :utc_datetime_usec
    end
  end
end
