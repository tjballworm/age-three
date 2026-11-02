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
    assert city.resources["gold"]["perHour"] == 100 + div(city.population["max"] * 50, 100)
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

  # A new player whose city also has an Academy and a Farm at Lv1, as if they had built them
  defp scholar(name) do
    {:ok, id} = Pg.find_or_create_player(name)
    now = System.system_time(:millisecond)
    {:ok, _, [city], []} = Pg.state(id, now)

    Age3.Repo.insert_all(
      Age3.Building,
      [
        %{city_id: city.id, slot: "0", type: "academy", level: 1},
        %{city_id: city.id, slot: "f0", type: "farm", level: 1},
        %{city_id: city.id, slot: "townhall", type: "townhall", level: 2}
      ],
      on_conflict: {:replace, [:level]},
      conflict_target: [:city_id, :slot]
    )

    {id, city.id, now}
  end

  test "research pays now, one at a time per Academy, and raises production when done" do
    {id, city_id, now} = scholar("Scholar")
    {:ok, player, [city], []} = Pg.state(id, now)
    assert player.research == %{}
    food = city.resources["food"]["amount"]

    assert {:ok, ends_at} = Pg.research(id, city_id, "agriculture", now)
    assert ends_at == now + 400_000
    assert {:error, "research_busy"} = Pg.research(id, city_id, "lumbering", now)
    # the Academy can't be upgraded while it researches
    assert {:error, "academy_busy"} = Pg.build(id, city_id, "0", nil, now)

    {:ok, _, [city], [task]} = Pg.state(id, now)
    assert %{kind: "research", targetType: "agriculture", targetLevel: 1, label: "Agriculture → Lv 1"} = task
    assert_in_delta city.resources["food"]["amount"], food - 500, 1

    {:ok, player, [city], []} = Pg.state(id, ends_at)
    assert player.research == %{"agriculture" => 1}
    farm = Age3.Data.level("farm", 1)["perHour"]
    assert city.resources["food"]["perHour"] == 100 + div(farm * 110, 100)

    # Lv2 needs Academy Lv2
    assert {:error, "requirement_not_met"} = Pg.research(id, city_id, "agriculture", ends_at)
  end

  test "an Academy being upgraded can't start a research" do
    {id, city_id, now} = scholar("Upgrader")
    {:ok, _} = Pg.build(id, city_id, "0", nil, now)
    assert {:error, "academy_busy"} = Pg.research(id, city_id, "agriculture", now)
  end

  test "cancel_research refunds the cost, and speed_up finishes a research in its last 5 minutes" do
    {id, city_id, now} = scholar("Refunder")
    {:ok, _, [city], []} = Pg.state(id, now)
    gold = city.resources["gold"]["amount"]

    {:ok, _} = Pg.research(id, city_id, "agriculture", now)
    {:ok, _, _, [task]} = Pg.state(id, now)
    assert {:error, "bad_message"} = Pg.cancel_build(id, city_id, task.id, now)
    assert :ok = Pg.cancel_research(id, city_id, task.id, now)
    {:ok, _, [city], []} = Pg.state(id, now)
    assert_in_delta city.resources["gold"]["amount"], gold, 1

    {:ok, ends_at} = Pg.research(id, city_id, "agriculture", now)
    {:ok, _, _, [task]} = Pg.state(id, now)
    assert :ok = Pg.speed_up(id, city_id, task.id, ends_at - 300_000)
    {:ok, player, _, []} = Pg.state(id, ends_at - 300_000)
    assert player.research == %{"agriculture" => 1}
  end

  # A new player whose city has a Barracks Lv2 on plot 4 (and a Rally Spot, Town Hall Lv3, cottages for a
  # population of 1000), as if they had built them, and plenty of resources.
  defp general(name) do
    {:ok, id} = Pg.find_or_create_player(name)
    now = System.system_time(:millisecond)
    {:ok, _, [city], []} = Pg.state(id, now)

    Age3.Repo.insert_all(
      Age3.Building,
      [
        %{city_id: city.id, slot: "4", type: "barracks", level: 2},
        %{city_id: city.id, slot: "5", type: "rallyspot", level: 1},
        %{city_id: city.id, slot: "6", type: "cottage", level: 3},
        %{city_id: city.id, slot: "7", type: "cottage", level: 2},
        %{city_id: city.id, slot: "townhall", type: "townhall", level: 3}
      ],
      on_conflict: {:replace, [:level]},
      conflict_target: [:city_id, :slot]
    )

    rich = Map.new(city.resources, fn {k, v} -> {k, %{v | "amount" => 1_000_000}} end)

    Age3.Repo.query!("UPDATE cities SET resources = $1, population = $2 WHERE id = $3", [
      rich,
      %{"current" => 1000, "max" => 1000, "idle" => 1000},
      Ecto.UUID.dump!(city.id)
    ])

    {id, city.id, now}
  end

  test "train pays and takes people now, queues batches one after another, and adds troops when done" do
    {id, city_id, now} = general("General")
    {:ok, _, [city], []} = Pg.state(id, now)
    food = city.resources["food"]["amount"]

    # 10 warriors take 240 s, the next 20 start when they end
    assert {:ok, first} = Pg.train(id, city_id, "4", "warrior", 10, now)
    assert first == now + 240_000
    assert {:ok, second} = Pg.train(id, city_id, "4", "warrior", 20, now)
    assert second == first + 480_000

    {:ok, _, [city], [a, b]} = Pg.state(id, now)
    assert %{kind: "train", label: "10 × Warrior", slot: "4", targetType: "warrior", targetLevel: 10} = a
    assert %{startedAt: ^first, endsAt: ^second} = b
    assert_in_delta city.resources["food"]["amount"], food - 30 * 80, 1
    assert_in_delta city.population["idle"], 1000 - 30, 1
    # the Barracks isn't shown as under construction
    assert %{type: "barracks", level: 2, slot: 4} in city.buildings
    assert city.troops == %{}

    {:ok, _, [city], [_]} = Pg.state(id, first)
    assert city.troops == %{"warrior" => 10}
    # warriors eat 1 food an hour each
    assert city.resources["food"]["perHour"] == 100 - 10

    {:ok, _, [city], []} = Pg.state(id, second)
    assert city.troops == %{"warrior" => 30}
    assert city.resources["food"]["perHour"] == 100 - 30
  end

  test "people move back in over time" do
    {id, city_id, now} = general("Recruiter")
    {:ok, _} = Pg.train(id, city_id, "4", "warrior", 100, now)
    {:ok, _, [city], _} = Pg.state(id, now)
    assert_in_delta city.population["current"], 900, 1

    # at 10% tax: 45% of the limit an hour, so full again within the hour
    {:ok, _, [city], _} = Pg.state(id, now + 600_000)
    assert_in_delta city.population["current"], 900 + 1000 * 0.45 / 6, 1
    {:ok, _, [city], _} = Pg.state(id, now + 3_600_000)
    assert city.population["current"] == 1000
  end

  test "not enough people" do
    {id, city_id, now} = general("Lonely")
    assert {:error, "not_enough_population"} = Pg.train(id, city_id, "4", "warrior", 1001, now)
    assert {:error, "bad_slot"} = Pg.train(id, city_id, "5", "warrior", 1, now)
  end

  test "cancel_train refunds cost and people, and the batches behind move up" do
    {id, city_id, now} = general("Deserter")
    {:ok, _, [city], []} = Pg.state(id, now)
    food = city.resources["food"]["amount"]

    {:ok, first} = Pg.train(id, city_id, "4", "warrior", 10, now)
    {:ok, _} = Pg.train(id, city_id, "4", "warrior", 20, now)
    {:ok, _, _, [a, _b]} = Pg.state(id, now)

    # cancelling the running batch halfway: the next one starts now
    half = now + 120_000
    assert {:error, "bad_message"} = Pg.cancel_build(id, city_id, a.id, half)
    assert :ok = Pg.cancel_train(id, city_id, a.id, half)
    {:ok, _, [city], [b]} = Pg.state(id, half)
    assert %{startedAt: ^half, targetLevel: 20} = b
    assert b.endsAt == half + 480_000
    assert_in_delta city.resources["food"]["amount"], food - 20 * 80, 2
    # 30 went in, 10 came back, and people moved back in for 120 s at 45% of 1000 an hour
    assert_in_delta city.population["current"], 980 + 1000 * 0.45 * 120 / 3600, 1
    assert first > half
  end

  test "speed_up finishes the batch in its last 5 minutes, not one still waiting" do
    {id, city_id, now} = general("Hurrier")
    {:ok, first} = Pg.train(id, city_id, "4", "warrior", 10, now)
    {:ok, _} = Pg.train(id, city_id, "4", "warrior", 1, now)
    {:ok, _, _, [a, b]} = Pg.state(id, now)

    # the second batch ends within 5 minutes, but hasn't started
    assert {:error, "too_early"} = Pg.speed_up(id, city_id, b.id, now)
    assert :ok = Pg.speed_up(id, city_id, a.id, now)
    {:ok, _, [city], [b]} = Pg.state(id, now)
    assert city.troops == %{"warrior" => 10}
    assert %{startedAt: ^now} = b
    assert b.endsAt == now + 24_000
    assert first > now
  end

  test "a Barracks upgrades while it trains, and trains while it is upgraded" do
    {id, city_id, now} = general("Builder General")
    # each batch of 100 warriors takes 40 minutes, longer than the 20-minute upgrade
    {:ok, _} = Pg.train(id, city_id, "4", "warrior", 100, now)
    assert {:ok, built} = Pg.build(id, city_id, "4", nil, now)
    # a Lv2 Barracks: one training and two waiting
    assert {:ok, _} = Pg.train(id, city_id, "4", "warrior", 100, now)
    assert {:ok, _} = Pg.train(id, city_id, "4", "warrior", 100, now)
    assert {:error, "train_queue_full"} = Pg.train(id, city_id, "4", "warrior", 100, now)
    # at Lv3 a third can wait
    assert {:ok, _} = Pg.train(id, city_id, "4", "warrior", 100, built)
  end

  test "state for an unknown player" do
    assert {:error, :not_found} = Pg.state(Ecto.UUID.generate(), 0)
    assert {:error, :not_found} = Pg.state("not-a-uuid", 0)
  end
end
