defmodule Age3.MarketOrder do
  # An open Marketplace order (Age3.Market): amount left, price in thousandths of a gold per unit.
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "market_orders" do
    field :city_id, :binary_id
    field :player_id, :binary_id
    field :side, :string
    field :resource, :string
    field :amount, :integer
    field :price, :integer
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end

defmodule Age3.MarketTrade do
  # One trade on the Marketplace, for the last price.
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "market_trades" do
    field :resource, :string
    field :amount, :integer
    field :price, :integer
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
