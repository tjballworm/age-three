defmodule Age3.Report do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "battle_reports" do
    belongs_to :player, Age3.Player
    field :city_id, :binary_id
    field :title, :string
    field :x, :integer
    field :y, :integer
    field :won, :boolean
    field :loot, :map, default: %{}
    # medals the battle dropped, e.g. %{"rose" => 1}
    field :medals, :map, default: %{}
    # "attack" or "defence": each side of a battle with a player gets its own report
    field :side, :string, default: "attack"
    # a player city's loyalty: %{"before", "after", "captured"}; nil for NPC battles
    field :loyalty, :map
    field :hero, :map

    # a policy report (side "policy" or "policied"): %{"policy", "from", "to", "taken"}; no battle, so no result
    field :policy, :map
    # a scout report (kind "scout"): what was seen (Age3.Scout.report/2); no battle, so no result
    field :scout, :map
    # "battle" (with a result), "scout", "transport", "reinforce", "found" or "valley" (a mission's report)
    field :kind, :string, default: "battle"
    field :result, :map
    field :read, :boolean, default: false
    field :fought_at, :utc_datetime_usec
  end
end
