defmodule Age3.Repo.Migrations.ItemsQuests do
  # Items and quests (Age3.Items, Age3.Quests). players.items: %{item_id => count}. players.quests: the ids of
  # quests whose reward has been claimed.
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :items, :map, null: false, default: %{}
      add :quests, {:array, :string}, null: false, default: []
    end
  end
end
