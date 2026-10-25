defmodule Age3.Store.PgTest do
  # The real store against Postgres. Run with: mix test --include db
  use ExUnit.Case, async: true

  @moduletag :db

  alias Age3.Store.Pg

  setup do
    # each test runs in a transaction that is rolled back afterwards, so tests leave no rows behind
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
  end

  test "login creates a player with a starter city, and finds them again" do
    {:ok, id} = Pg.login("Test Lord")
    assert {:ok, ^id} = Pg.login("Test Lord")

    {:ok, player, [city]} = Pg.state(id)
    assert %{name: "Test Lord", title: "Civilian", alliance: nil, rank: 0} = player
    assert city.name == "Test Lord's Town"
    assert city.x in 0..99 and city.y in 0..99
    assert %{"gold" => %{"amount" => 5000, "perHour" => 100, "cap" => 100_000}} = city.resources

    assert Enum.sort_by(city.buildings, & &1.slot) == [
             %{type: "townhall", level: 1, slot: "townhall"},
             %{type: "walls", level: 1, slot: "walls"}
           ]
  end

  test "state for an unknown player" do
    assert {:error, :not_found} = Pg.state(Ecto.UUID.generate())
    assert {:error, :not_found} = Pg.state("not-a-uuid")
  end
end
