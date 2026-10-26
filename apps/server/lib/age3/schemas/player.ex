defmodule Age3.Player do
  # A row in the players table. An Ecto schema maps a table's columns to an Elixir struct, %Age3.Player{}.
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "players" do
    field :name, :string
    field :title, :string, default: "Civilian"
    field :alliance, :string
    field :prestige, :integer, default: 0
    field :honor, :integer, default: 0
    has_many :cities, Age3.City
  end
end
