defmodule Age3.Store.PgTest do
  # The real store against Postgres. Run with: mix test --include db
  use ExUnit.Case, async: true

  @moduletag :db

  alias Age3.Store.Pg

  setup do
    # each test runs in a transaction that is rolled back afterwards, so tests leave no rows behind
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
  end

  test "find_or_create_player creates a player with a starter city, and finds them again" do
    {:ok, id} = Pg.find_or_create_player("Test Lord")
    assert {:ok, ^id} = Pg.find_or_create_player("Test Lord")

    {:ok, player, [city], []} = Pg.state(id, System.system_time(:millisecond))
    assert %{name: "Test Lord", title: "Civilian", alliance: nil, rank: 0} = player
    assert city.name == "Test Lord's Town"
    assert city.x in 0..799 and city.y in 0..799
    # settled to now, so a moment's production may have been added
    assert %{"gold" => %{"amount" => gold, "perHour" => 100, "cap" => 100_000}} = city.resources
    assert_in_delta gold, 5000, 1

    assert Enum.sort_by(city.buildings, & &1.slot) == [
             %{type: "townhall", level: 1, slot: "townhall"},
             %{type: "walls", level: 1, slot: "walls"}
           ]

    assert city.fields == []
  end

  test "build pays now, finishes when due, and one build at a time" do
    {:ok, id} = Pg.find_or_create_player("Builder")
    now = System.system_time(:millisecond)
    {:ok, _, [city], []} = Pg.state(id, now)

    assert {:ok, ends_at} = Pg.build(id, city.id, "3", "cottage", now)
    assert ends_at == now + Age3.Data.level("cottage", 1)["seconds"] * 1000
    assert {:error, "queue_busy"} = Pg.build(id, city.id, "f0", "farm", now)

    {:ok, _, [city], [task]} = Pg.state(id, now)
    assert %{targetType: "cottage", targetLevel: 1, slot: "3", endsAt: ^ends_at} = task
    lumber = Age3.Data.level("cottage", 1)["cost"]["lumber"]
    assert_in_delta city.resources["lumber"]["amount"], 10_000 - lumber, 1

    # once due, reading the state finishes it
    {:ok, _, [city], []} = Pg.state(id, ends_at)
    assert %{type: "cottage", level: 1, slot: 3} in city.buildings
  end

  test "cancel refunds the cost" do
    {:ok, id} = Pg.find_or_create_player("Canceller")
    now = System.system_time(:millisecond)
    {:ok, _, [city], []} = Pg.state(id, now)
    {:ok, _} = Pg.build(id, city.id, "f0", "farm", now)
    {:ok, _, _, [task]} = Pg.state(id, now)

    assert :ok = Pg.cancel_build(id, city.id, task.id, now)
    {:ok, _, [city], []} = Pg.state(id, now)
    assert_in_delta city.resources["lumber"]["amount"], 10_000, 1
    assert city.fields == []
  end

  test "state for an unknown player" do
    assert {:error, :not_found} = Pg.state(Ecto.UUID.generate(), 0)
    assert {:error, :not_found} = Pg.state("not-a-uuid", 0)
  end
end
