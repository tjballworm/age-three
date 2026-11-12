defmodule Age3.Repo.Migrations.Wounded do
  # Wounded troops (Age3.Heal): cities.wounded holds them, %{"warrior" => 10, ...}, until they are healed for gold
  # in the Rally Spot.
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :wounded, :map, null: false, default: %{}
    end
  end
end
