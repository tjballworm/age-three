defmodule Age3.Repo.Migrations.Market do
  # The Marketplace's order book (Age3.Market). market_orders: open orders, amount being what is left and price in
  # thousandths of a gold per unit; a sell order holds its resource, a buy order amount * price / 1000 gold.
  # market_trades: every trade, for the last price.
  use Ecto.Migration

  def change do
    create table(:market_orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :city_id, references(:cities, type: :binary_id, on_delete: :delete_all), null: false
      add :player_id, references(:players, type: :binary_id, on_delete: :delete_all), null: false
      add :side, :string, null: false
      add :resource, :string, null: false
      add :amount, :bigint, null: false
      add :price, :integer, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:market_orders, [:resource, :side, :price])
    create index(:market_orders, [:city_id])

    create table(:market_trades, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :resource, :string, null: false
      add :amount, :bigint, null: false
      add :price, :integer, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:market_trades, [:resource, :inserted_at])
  end
end
