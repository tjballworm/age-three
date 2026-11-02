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
    assert %{"gold" => %{"amount" => gold, "perHour" => 110, "cap" => 100_000}} = city.resources
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

  test "a finished farm raises food production from the moment it finished" do
    {:ok, id} = Pg.find_or_create_player("Farmer")
    now = System.system_time(:millisecond)
    {:ok, _, [city], []} = Pg.state(id, now)
    {:ok, ends_at} = Pg.build(id, city.id, "f0", "farm", now)
    {:ok, _, [before], _} = Pg.state(id, ends_at)
    food = before.resources["food"]["amount"]

    # an hour later: food grew at the new rate, base 100 plus the farm's
    {:ok, _, [city], []} = Pg.state(id, ends_at + 3_600_000)
    rate = 100 + Age3.Data.level("farm", 1)["perHour"]
    assert city.resources["food"]["perHour"] == rate
    assert_in_delta city.resources["food"]["amount"], food + rate, 1
  end

  test "speed_up finishes a build with 5 minutes or less left" do
    {:ok, id} = Pg.find_or_create_player("Speeder")
    now = System.system_time(:millisecond)
    {:ok, _, [city], []} = Pg.state(id, now)
    {:ok, ends_at} = Pg.build(id, city.id, "3", "cottage", now)
    {:ok, _, _, [task]} = Pg.state(id, now)

    # a moment more than 5 minutes before the end is too early
    early = ends_at - Age3.Data.free_speedup_ms() - 1_000
    assert {:error, "too_early"} = Pg.speed_up(id, city.id, task.id, early)

    late = max(now, ends_at - Age3.Data.free_speedup_ms())
    assert :ok = Pg.speed_up(id, city.id, task.id, late)
    {:ok, _, [city], []} = Pg.state(id, late)
    assert %{type: "cottage", level: 1, slot: 3} in city.buildings
    assert city.population["max"] == 100 + Age3.Data.level("cottage", 1)["population"]
    assert {:error, "bad_message"} = Pg.speed_up(id, city.id, task.id, late)
  end

  test "set_tax changes gold per hour from now on" do
    {:ok, id} = Pg.find_or_create_player("Taxman")
    now = System.system_time(:millisecond)
    {:ok, _, [city], []} = Pg.state(id, now)

    assert :ok = Pg.set_tax(id, city.id, 50, now)
    {:ok, _, [city], []} = Pg.state(id, now)
    assert city.taxRate == 50
    assert city.resources["gold"]["perHour"] == 100 + div(city.population["current"] * 50, 100)
  end

  test "a city with old rates gets the new ones on its next state" do
    {:ok, id} = Pg.find_or_create_player("Oldtimer")
    now = System.system_time(:millisecond)
    {:ok, _, [city], []} = Pg.state(id, now)

    old = Map.new(city.resources, fn {k, v} -> {k, %{v | "perHour" => 200, "cap" => 5}} end)
    old_population = %{"current" => 100, "max" => 500, "idle" => 100}

    Age3.Repo.query!("UPDATE cities SET resources = $1, population = $2 WHERE id = $3", [
      old,
      old_population,
      Ecto.UUID.dump!(city.id)
    ])

    {:ok, _, [city], []} = Pg.state(id, now)
    assert city.resources["food"]["perHour"] == 100
    assert city.resources["food"]["cap"] == 100_000
    assert city.population["max"] == 100
  end

  test "state for an unknown player" do
    assert {:error, :not_found} = Pg.state(Ecto.UUID.generate(), 0)
    assert {:error, :not_found} = Pg.state("not-a-uuid", 0)
  end
end
