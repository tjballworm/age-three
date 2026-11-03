defmodule Age3.Repo.Migrations.HeroStars do
  # A hero's gear stars, 0-15. In battle they multiply the life of the troops the hero leads and the hero's
  # Leadership coverage (Age3.Combat.Units.star_multipliers). Gear doesn't exist yet, so only the setHero cheat
  # sets them for now.
  use Ecto.Migration

  def change do
    alter table(:heroes) do
      add :stars, :integer, null: false, default: 0
    end
  end
end
