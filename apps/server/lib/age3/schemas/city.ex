defmodule Age3.City do
  # A row in the cities table. resources and population are jsonb columns, read back as maps.
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "cities" do
    belongs_to :player, Age3.Player
    field :name, :string
    field :x, :integer
    field :y, :integer
    field :level, :integer, default: 1
    field :loyalty, :integer, default: 100
    field :tax_rate, :integer, default: 10
    field :resources, :map
    field :population, :map
    has_many :buildings, Age3.Building
  end
end
