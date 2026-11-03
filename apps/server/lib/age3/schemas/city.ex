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
    # loyalty and the population are part of the snapshot taken at synced_at (Age3.Economy.settle_city)
    field :loyalty, :integer, default: 100
    field :grievance, :integer, default: 0
    # the last Disaster Relief or Praying (Age3.Loyalty, 15 minute cooldown)
    field :comfort_at, :utc_datetime_usec

    # the Rally Spot's "open gate to fight": closed keeps the troops out of battles (they open by themselves at
    # loyalty 5 or less)
    field :gate_open, :boolean, default: false
    # the hero who leads the city's defence, chosen apart from the mayor (TJ, 2026-11-03)
    field :defender_hero_id, :binary_id
    field :tax_rate, :integer, default: 10
    field :resources, :map
    field :population, :map
    # trained troops, e.g. %{"warrior" => 100}; troops still training are tasks
    field :troops, :map, default: %{}
    field :inn, :map, default: %{}
    # when the resources snapshot was taken; Age3.Economy.settle works forward from here
    field :synced_at, :utc_datetime_usec
    has_many :buildings, Age3.Building
    has_many :heroes, Age3.Hero
  end
end
