defmodule Age3.Repo.Migrations.HeroGrowth do
  use Ecto.Migration

  # Hero loyalty and reward, and taking back spent stat points (plans/age2-features-plan.md, bundles 2 and 3).
  def change do
    alter table(:heroes) do
      add :loyalty, :integer, null: false, default: 70
      add :reward_at, :utc_datetime_usec
      add :added, :map, null: false, default: %{}
      add :reset_at, :utc_datetime_usec
    end

    # captives come in with no loyalty
    execute "UPDATE heroes SET loyalty = 0 WHERE status = 'captive'", ""
  end
end
