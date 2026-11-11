defmodule Age3.Repo.Migrations.Fortifications do
  # Players' wall fortifications (traps, abatis, archer towers, rolling logs, defensive trebuchets): cities.forts
  # holds the built ones, %{"trap" => 100, ...}. Batches being built are tasks of kind "fort" (Age3.Forts).
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :forts, :map, null: false, default: %{}
    end
  end
end
