defmodule Age3.NpcState do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "npc_states" do
    field :x, :integer, primary_key: true
    field :y, :integer, primary_key: true
    field :level, :integer
    field :troops, :map
    field :forts, :map
    field :resources, :map
    # a historic city's loyalty as of updated_at (Age3.Historic.loyalty/3); NPCs and lords' towns keep 100
    field :loyalty, :integer, default: 100
    field :updated_at, :utc_datetime_usec
  end
end
