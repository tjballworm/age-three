defmodule Age3.Repo.Migrations.Loyalty do
  # City loyalty is modelled now (Age3.Loyalty). cities.loyalty already existed (always 100); it becomes part of
  # the snapshot taken at synced_at, like resources and population. grievance is public grievance (0-100), and
  # comfort_at the last Disaster Relief or Praying, for the 15 minute cooldown.
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :grievance, :integer, null: false, default: 0
      add :comfort_at, :utc_datetime_usec
    end
  end
end
