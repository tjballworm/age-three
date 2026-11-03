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

  test "comfort pays the population limit and lifts loyalty, once every 15 minutes" do
    {id, city_id, now} = general("Comforter")

    assert {:ok, ^id} =
             Pg.cheat(id, {:city, city_id}, "setLoyalty", %{changes: [loyalty: 40, grievance: 30]}, now)

    {:ok, _, [city], _} = Pg.state(id, now)
    assert %{loyalty: 40, grievance: 30} = city
    gold = city.resources["gold"]["amount"]
    food = city.resources["food"]["amount"]

    assert :ok = Pg.comfort(id, city_id, "pray", now)
    {:ok, _, [city], _} = Pg.state(id, now)
    assert %{loyalty: 65, grievance: 25, comfortAt: ^now} = city
    assert_in_delta city.resources["gold"]["amount"], gold - 1000, 0.01

    assert {:error, "comfort_cooldown"} = Pg.comfort(id, city_id, "relief", now + 899_999)
    assert :ok = Pg.comfort(id, city_id, "relief", now + 900_000)
    {:ok, _, [city], _} = Pg.state(id, now + 900_000)
    # loyalty was already where it heads (100 - 10% tax - 25 grievance), so the ticks left it; then +5
    assert city.grievance == 10
    assert city.loyalty == 70
    assert_in_delta city.resources["food"]["amount"], food - 1000, 50
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

    # just after a loyalty tick (Age3.Loyalty), so the tests know when the next ones come: 6, 12, ... minutes on
    now = div(now, Age3.Loyalty.tick_ms()) * Age3.Loyalty.tick_ms() + 1

    Age3.Repo.query!("UPDATE cities SET resources = $1, population = $2, synced_at = $3 WHERE id = $4", [
      rich,
      %{"current" => 1000, "max" => 1000, "idle" => 1000},
      DateTime.from_unix!(now, :millisecond),
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
    # warriors eat 0.001 food an hour each, rounded up: any army eats at least 1
    assert city.resources["food"]["perHour"] == 100 - 1

    {:ok, _, [city], []} = Pg.state(id, second)
    assert city.troops == %{"warrior" => 30}
    assert city.resources["food"]["perHour"] == 100 - 1
  end

  test "people move back in over time" do
    {id, city_id, now} = general("Recruiter")
    {:ok, _} = Pg.train(id, city_id, "4", "warrior", 100, now)
    {:ok, _, [city], _} = Pg.state(id, now)
    assert_in_delta city.population["current"], 900, 1

    # every 6 minutes loyalty takes a step towards 100 - 10% tax = 90, and at 10% tax people move back in at
    # 4.5% of the limit, up to loyalty% of it
    {:ok, _, [city], _} = Pg.state(id, now + 360_000)
    assert city.loyalty == 99
    assert city.population["current"] == 945
    {:ok, _, [city], _} = Pg.state(id, now + 720_000)
    assert city.loyalty == 98
    assert city.population["current"] == 980

    # after 10 ticks loyalty is 90; above the line people leave at 0.5% of the limit a tick, down to 900
    {:ok, _, [city], _} = Pg.state(id, now + 3 * 3_600_000)
    assert city.loyalty == 90
    assert city.population["current"] == 900
    # and gold comes from them: 10% of 900
    assert city.resources["gold"]["perHour"] == 100 + 90
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
    # 30 went in and 10 came back; no loyalty tick yet, so nobody moved back in
    assert city.population["current"] == 980
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

  describe "heroes" do
    # a city with an Inn and a Feasting Hall, both Lv2, and plenty of gold
    defp innkeeper(name) do
      {id, city_id, now} = general(name)

      Age3.Repo.insert_all(Age3.Building, [
        %{city_id: city_id, slot: "8", type: "inn", level: 2},
        %{city_id: city_id, slot: "9", type: "feastinghall", level: 2}
      ])

      {id, city_id, now}
    end

    test "the Inn offers Inn-level heroes; hiring pays the fee and the salary comes off gold" do
      {id, city_id, now} = innkeeper("Hirer")
      {:ok, _, [city], _} = Pg.state(id, now)
      assert %{refreshAt: refresh_at, offers: [offer, _]} = city.inn
      assert refresh_at > now
      assert city.heroes == []
      gold = city.resources["gold"]
      assert offer.fee == offer.level * 1000

      assert :ok = Pg.hire(id, city_id, offer.id, now)
      {:ok, _, [city], _} = Pg.state(id, now)
      assert [hero] = city.heroes

      assert %{name: name, level: level, leadership: level, status: "idle", exp: 0, points: 0} = hero
      assert name == offer.name and level == offer.level
      assert hero.salary == level * 20
      assert_in_delta city.resources["gold"]["amount"], gold["amount"] - offer.fee, 1
      assert city.resources["gold"]["perHour"] == gold["perHour"] - level * 20
      # the hired hero left the Inn, and can't be hired twice
      assert [_] = city.inn.offers
      assert {:error, "offer_gone"} = Pg.hire(id, city_id, offer.id, now)

      # same offers until refreshAt, then a new set
      {:ok, _, [same], _} = Pg.state(id, refresh_at - 1)
      assert same.inn == city.inn
      {:ok, _, [later], _} = Pg.state(id, refresh_at)
      assert length(later.inn.offers) == 2 and later.inn.offers != city.inn.offers
    end

    test "the free refresh rolls new offers now and keeps the timer" do
      {id, city_id, now} = innkeeper("Refresher")
      {:ok, _, [city], _} = Pg.state(id, now)
      [old | _] = city.inn.offers

      assert :ok = Pg.reroll_inn(id, city_id, now + 1)
      {:ok, _, [fresh], _} = Pg.state(id, now + 1)
      assert fresh.inn.refreshAt == city.inn.refreshAt
      assert length(fresh.inn.offers) == 2 and fresh.inn.offers != city.inn.offers
      # the old offers are gone
      assert {:error, "offer_gone"} = Pg.hire(id, city_id, old.id, now + 1)

      {id, city_id, now} = general("No Inn To Refresh")
      assert {:error, "no_inn"} = Pg.reroll_inn(id, city_id, now)
    end

    test "the Feasting Hall's level limits the heroes" do
      {id, city_id, now} = innkeeper("Collector")
      {:ok, _, [city], _} = Pg.state(id, now)
      [a, b] = city.inn.offers
      assert :ok = Pg.hire(id, city_id, a.id, now)
      assert :ok = Pg.hire(id, city_id, b.id, now)

      # next set of offers, but the Lv2 Hall is full
      {:ok, _, [city], _} = Pg.state(id, city.inn.refreshAt)
      [c | _] = city.inn.offers
      assert {:error, "hall_full"} = Pg.hire(id, city_id, c.id, city.inn.refreshAt)
    end

    test "one mayor at a time; a mayor can't be dismissed; dismissing stops the salary" do
      {id, city_id, now} = innkeeper("Mayor Maker")
      {:ok, _, [city], _} = Pg.state(id, now)
      for o <- city.inn.offers, do: :ok = Pg.hire(id, city_id, o.id, now)
      {:ok, _, [city], _} = Pg.state(id, now)
      [a, b] = city.heroes

      assert :ok = Pg.set_mayor(id, city_id, a.id, now)
      assert :ok = Pg.set_mayor(id, city_id, b.id, now)
      {:ok, _, [city], _} = Pg.state(id, now)

      assert Enum.map(city.heroes, &{&1.id, &1.status}) |> Enum.sort() ==
               Enum.sort([{a.id, "idle"}, {b.id, "mayor"}])

      assert {:error, "hero_busy"} = Pg.dismiss(id, city_id, b.id, now)
      assert :ok = Pg.set_mayor(id, city_id, nil, now)
      gold_rate = city.resources["gold"]["perHour"]
      assert :ok = Pg.dismiss(id, city_id, b.id, now)
      {:ok, _, [city], _} = Pg.state(id, now)
      assert [%{status: "idle"}] = city.heroes
      assert city.resources["gold"]["perHour"] == gold_rate + b.salary

      assert {:error, "bad_message"} = Pg.dismiss(id, city_id, b.id, now)
      assert {:error, "bad_message"} = Pg.set_mayor(id, city_id, "not-a-uuid", now)
    end

    test "no Inn, no offers; the heroExp cheat levels heroes up" do
      {id, city_id, now} = general("No Inn")
      {:ok, _, [city], _} = Pg.state(id, now)
      assert city.inn == nil
      assert {:error, "no_inn"} = Pg.hire(id, city_id, "x", now)

      {id, city_id, now} = innkeeper("Trainer")
      {:ok, _, [city], _} = Pg.state(id, now)
      [o | _] = city.inn.offers
      :ok = Pg.hire(id, city_id, o.id, now)
      assert {:ok, ^id} = Pg.cheat(id, {:city, city_id}, "heroExp", %{amount: 100 * o.level * o.level}, now)
      {:ok, _, [city], _} = Pg.state(id, now)
      assert [%{level: level, leadership: level, points: 1}] = city.heroes
      assert level == o.level + 1
    end

    test "the setHero cheat sets one hero's level and stats" do
      {id, city_id, now} = innkeeper("Statter")
      {:ok, _, [city], _} = Pg.state(id, now)
      [o | _] = city.inn.offers
      :ok = Pg.hire(id, city_id, o.id, now)
      {:ok, _, [%{heroes: [hero]}], _} = Pg.state(id, now)

      {:ok, args} =
        Age3.Cheats.parse("setHero", %{
          "heroId" => hero.id,
          "level" => 80,
          "attack" => 500,
          "points" => 3,
          "stars" => 9
        })

      assert {:ok, ^id} = Pg.cheat(id, {:city, city_id}, "setHero", args, now)
      {:ok, _, [city], _} = Pg.state(id, now)

      assert [%{level: 80, leadership: 80, attack: 500, points: 3, exp: 0, stars: 9} = h] = city.heroes
      assert h.politics == hero.politics and h.intelligence == hero.intelligence
      assert h.salary == Age3.Heroes.salary(80)

      # someone else's hero, or one that's gone
      {other, other_city, _} = general("Bystander")
      assert {:error, "hero_not_found"} = Pg.cheat(other, {:city, other_city}, "setHero", args, now)

      gone = %{args | hero_id: Ecto.UUID.generate()}
      assert {:error, "hero_not_found"} = Pg.cheat(id, {:city, city_id}, "setHero", gone, now)
      # by username it reaches the hero too
      {:ok, args} = Age3.Cheats.parse("setHero", %{"heroId" => hero.id, "intelligence" => 9999})
      assert {:ok, ^id} = Pg.cheat(other, {:player, "Statter"}, "setHero", args, now)
    end
  end

  describe "marches" do
    # a general's city with an idle Lv5 hero, 5,000 cavalry and the nearest Lv1 NPC
    defp warlord(name) do
      {id, city_id, now} = general(name)
      city = Age3.Repo.get!(Age3.City, city_id)

      hero =
        Age3.Repo.insert!(%Age3.Hero{
          city_id: city_id,
          name: "Hector",
          level: 5,
          politics: 30,
          attack: 50,
          intelligence: 40
        })

      {:ok, _} = Pg.cheat(id, {:city, city_id}, "addTroops", %{troops: %{"cavalry" => 5000}}, now)

      target =
        for(d <- 1..80, dx <- -d..d, dy <- [-d, d], do: {city.x + dx, city.y + dy})
        |> Enum.map(fn {x, y} -> {Integer.mod(x, 800), Integer.mod(y, 800)} end)
        |> Enum.find(fn {x, y} -> Age3.World.tile_at(x, y) == %{kind: "npc", level: 1} end)

      {id, city_id, hero.id, target, now}
    end

    test "a march takes troops, hero and food, fights on arrival, comes back with loot and leaves a report" do
      {id, city_id, hero_id, {x, y}, now} = warlord("Attacker")
      {:ok, _, [city], _} = Pg.state(id, now)
      food = city.resources["food"]

      assert {:ok, arrives} = Pg.march(id, city_id, x, y, hero_id, %{"cavalry" => 1000}, now)
      {:ok, _, [city], [task]} = Pg.state(id, now)
      assert city.troops["cavalry"] == 4000
      assert [%{status: "marching"}] = city.heroes
      assert %{kind: "march", endsAt: ^arrives, march: %{phase: "out", x: ^x, y: ^y, heroId: ^hero_id}} = task
      seconds = div(arrives - now, 1000)

      assert_in_delta city.resources["food"]["amount"],
                      food["amount"] - Age3.March.food(%{"cavalry" => 1000}, seconds),
                      1

      # fewer troops at home eat less
      assert city.resources["food"]["perHour"] > food["perHour"]
      assert {:error, "hero_busy"} = Pg.march(id, city_id, x, y, hero_id, %{"cavalry" => 1}, now)

      # arrived: the battle is won, the NPC is emptied and the march turns home
      {:ok, player, [city], [back]} = Pg.state(id, arrives)
      assert %{march: %{phase: "back", troops: %{"cavalry" => survivors}, loot: loot}} = back
      assert back.endsAt == arrives + seconds * 1000
      assert survivors > 0 and survivors <= 1000
      # 1,000 cavalry can't carry it all: a share of each resource
      assert loot ==
               Age3.March.loot(Age3.Npc.full(1)["resources"], Age3.March.load(%{"cavalry" => survivors}, %{}))

      assert player.unreadReports == 1
      # a full clear of a full NPC: whatever medals it dropped are the player's already
      assert [%{medals: medals}] = Pg.reports(id)
      assert player.medals == medals
      assert Enum.all?(Map.keys(medals), &(&1 in ["cross", "rose"]))
      assert [%{status: "marching", exp: exp}] = city.heroes
      assert exp > 0

      npc = Age3.Repo.get_by!(Age3.NpcState, x: x, y: y)
      assert Enum.all?(Map.values(npc.troops), &(&1 == 0))
      assert npc.resources == Map.new(Age3.Npc.full(1)["resources"], fn {k, v} -> {k, v - loot[k]} end)

      # home: troops back, hero idle, loot in storage
      {:ok, _, [home], []} = Pg.state(id, back.endsAt)
      assert home.troops["cavalry"] == 4000 + survivors
      assert [%{status: "idle"}] = home.heroes
      assert home.resources["gold"]["amount"] >= city.resources["gold"]["amount"] + loot["gold"]

      # the report, then the whole battle
      assert [%{id: report_id, won: true, read: false, loot: ^loot, hero: %{"name" => "Hector"}}] =
               Pg.reports(id)

      assert {:ok, %{result: %{"winner" => "attacker", "log" => [_ | _]}}} = Pg.report(id, report_id)
      assert [%{read: true}] = Pg.reports(id)
      assert {:error, "bad_message"} = Pg.report(id, Ecto.UUID.generate())

      # the NPC refills a little every second
      {:ok, _} = Pg.cheat(id, {:city, city_id}, "addTroops", %{troops: %{"warrior" => 1}}, now)
      later = back.endsAt + 1800 * 1000
      {:ok, _} = Pg.march(id, city_id, x, y, hero_id, %{"cavalry" => 1000}, later)
      {:ok, _, _, [again]} = Pg.state(id, later)
      {:ok, _, _, [_back]} = Pg.state(id, again.endsAt)
      [newest | _] = Pg.reports(id)
      {:ok, %{result: r}} = Pg.report(id, newest.id)
      warriors = Enum.find(r["defender"]["troops"], &(&1["type"] == "warrior"))["initial"]
      assert warriors == min(50, div(50 * div(again.endsAt - arrives, 1000), 3600))
      # not at full strength: no medals
      assert newest.medals == %{}
    end

    test "a march finishes in one go even when its return is already due; recall turns it around" do
      {id, city_id, hero_id, {x, y}, now} = warlord("Returner")
      {:ok, arrives} = Pg.march(id, city_id, x, y, hero_id, %{"cavalry" => 100}, now)
      {:ok, _, [city], []} = Pg.state(id, arrives + 10 * (arrives - now))
      assert city.troops["cavalry"] > 4000
      assert [%{status: "idle"}] = city.heroes

      {:ok, _} = Pg.march(id, city_id, x, y, hero_id, %{"cavalry" => 100}, now)
      {:ok, _, _, [task]} = Pg.state(id, now)
      assert {:ok, home} = Pg.recall(id, city_id, task.id, now + 5000)
      assert home == now + 10_000
      assert {:error, "already_returning"} = Pg.recall(id, city_id, task.id, now + 6000)
      {:ok, _, [city], []} = Pg.state(id, home)
      assert [%{status: "idle"}] = city.heroes
      assert Pg.reports(id) |> length() == 1
    end

    test "instant march cheat: a second each way; errors" do
      {id, city_id, hero_id, {x, y}, now} = warlord("Flash")
      {:ok, _, [home], _} = Pg.state(id, now)
      assert {:error, "bad_target"} = Pg.march(id, city_id, home.x, home.y, hero_id, %{"cavalry" => 1}, now)
      assert {:error, "no_hero"} = Pg.march(id, city_id, x, y, Ecto.UUID.generate(), %{"cavalry" => 1}, now)
      {:ok, ^id} = Pg.cheat(id, {:city, city_id}, "instantMarch", %{on: true}, now)
      {:ok, player, _, _} = Pg.state(id, now)
      assert player.instantMarch
      assert {:ok, arrives} = Pg.march(id, city_id, x, y, hero_id, %{"cavalry" => 100}, now)
      assert arrives == now + 1000
    end
  end

  describe "promotions" do
    test "ranks need the Town Hall, titles the rank; both take gold and medals and give prestige" do
      {id, city_id, now} = general("Climber")
      # Lieutenant: Town Hall 2 (the general's is 3), 10,000 gold, no medals
      assert :ok = Pg.promote(id, city_id, :rank, now)
      assert {:error, "not_enough_medals"} = Pg.promote(id, city_id, :title, now)

      {:ok, _} =
        Pg.cheat(id, {:player, "Climber"}, "addMedals", %{medals: %{"cross" => 17, "rose" => 5}}, now)

      # Captain needs Town Hall 4
      assert {:error, "requirement_not_met"} = Pg.promote(id, city_id, :rank, now)
      assert :ok = Pg.promote(id, city_id, :title, now)
      {:ok, _} = Pg.cheat(id, {:city, city_id}, "setBuilding", %{slot: "townhall", type: nil, level: 4}, now)
      assert :ok = Pg.promote(id, city_id, :rank, now)
      {:ok, player, [city], _} = Pg.state(id, now)

      assert %{title: "Knight", titleId: "knight", militaryRank: "Captain", cityCap: 2, prestige: 400} =
               player

      assert player.medals == %{"cross" => 2}
      assert_in_delta city.resources["gold"]["amount"], 1_000_000 - 10_000 - 20_000 - 20_000, 1

      # Baron needs Major
      {:ok, _} = Pg.cheat(id, {:player, "Climber"}, "setTitle", %{changes: [title: "baronet"]}, now)

      {:ok, _} =
        Pg.cheat(id, {:player, "Climber"}, "addMedals", %{medals: %{"lion" => 10, "honor" => 5}}, now)

      assert {:error, "rank_too_low"} = Pg.promote(id, city_id, :title, now)

      {:ok, _} =
        Pg.cheat(
          id,
          {:player, "Climber"},
          "setTitle",
          %{changes: [military_rank: "general", title: "prinzessin"]},
          now
        )

      assert {:error, "max_level"} = Pg.promote(id, city_id, :title, now)
      assert {:error, "bad_message"} = Pg.promote(id, Ecto.UUID.generate(), :rank, now)
    end
  end

  test "state for an unknown player" do
    assert {:error, :not_found} = Pg.state(Ecto.UUID.generate(), 0)
    assert {:error, :not_found} = Pg.state("not-a-uuid", 0)
  end

  describe "cheat" do
    test "gives resources, troops and population to a city" do
      {:ok, id} = Pg.find_or_create_player("Cheater")
      now = System.system_time(:millisecond)
      {:ok, _, [city], []} = Pg.state(id, now)
      target = {:city, city.id}

      assert {:ok, ^id} = Pg.cheat(id, target, "addResources", %{amounts: %{"gold" => 1_000_000}}, now)
      assert {:ok, ^id} = Pg.cheat(id, target, "addTroops", %{troops: %{"warrior" => 1000}}, now)
      assert {:ok, ^id} = Pg.cheat(id, target, "setPopulation", %{amount: 40}, now)

      {:ok, _, [city], []} = Pg.state(id, now)
      assert_in_delta city.resources["gold"]["amount"], 1_005_000, 1
      assert city.troops == %{"warrior" => 1000}
      # the troops eat, so food per hour went down
      assert city.resources["food"]["perHour"] < 100
      assert_in_delta city.population["current"], 40, 1

      assert {:ok, ^id} = Pg.cheat(id, target, "fillResources", %{}, now)
      {:ok, _, [city], []} = Pg.state(id, now)
      assert city.resources["stone"]["amount"] >= city.resources["stone"]["cap"]
    end

    test "works on any player by name, and on someone else's city only by name" do
      {:ok, me} = Pg.find_or_create_player("Tester A")
      {:ok, other} = Pg.find_or_create_player("Tester B")
      now = System.system_time(:millisecond)
      {:ok, _, [their_city], []} = Pg.state(other, now)

      assert {:error, "bad_message"} = Pg.cheat(me, {:city, their_city.id}, "fillResources", %{}, now)
      assert {:error, "player_not_found"} = Pg.cheat(me, {:player, "Nobody Here"}, "fillResources", %{}, now)

      assert {:ok, ^other} =
               Pg.cheat(me, {:player, "Tester B"}, "addTroops", %{troops: %{"archer" => 7}}, now)

      {:ok, _, [their_city], []} = Pg.state(other, now)
      assert their_city.troops == %{"archer" => 7}
    end

    test "finishAll finishes builds, research and training at once" do
      {:ok, id} = Pg.find_or_create_player("Impatient")
      now = System.system_time(:millisecond)
      {:ok, _, [city], []} = Pg.state(id, now)
      target = {:city, city.id}

      {:ok, _} = Pg.build(id, city.id, "3", "cottage", now)
      {:ok, _, _, [_task]} = Pg.state(id, now)
      assert {:ok, ^id} = Pg.cheat(id, target, "finishAll", %{}, now)

      {:ok, _, [city], []} = Pg.state(id, now)
      assert %{type: "cottage", level: 1, slot: 3} in city.buildings
    end

    test "sets buildings and research levels for free, and resets a city" do
      {:ok, id} = Pg.find_or_create_player("Architect")
      now = System.system_time(:millisecond)
      {:ok, _, [city], []} = Pg.state(id, now)
      target = {:city, city.id}

      assert {:ok, _} = Pg.cheat(id, target, "setBuilding", %{slot: "7", type: "academy", level: 5}, now)
      assert {:ok, _} = Pg.cheat(id, target, "setBuilding", %{slot: "f0", type: "farm", level: 3}, now)

      assert {:error, "bad_slot"} =
               Pg.cheat(id, target, "setBuilding", %{slot: "f1", type: "academy", level: 1}, now)

      assert {:ok, _} = Pg.cheat(id, target, "levelAll", %{level: 9}, now)
      assert {:ok, _} = Pg.cheat(id, target, "setResearch", %{tech: "agriculture", level: 4}, now)

      {:ok, player, [city], []} = Pg.state(id, now)
      assert %{type: "academy", level: 9, slot: 7} in city.buildings
      assert %{type: "townhall", level: 9, slot: "townhall"} in city.buildings
      assert %{type: "farm", level: 9, slot: 0} in city.fields
      assert player.research == %{"agriculture" => 4}
      gold = city.resources["gold"]["amount"]
      assert_in_delta gold, 5000, 1

      assert {:ok, _} = Pg.cheat(id, target, "setBuilding", %{slot: "f0", type: nil, level: 0}, now)
      assert {:ok, _} = Pg.cheat(id, {:player, "Architect"}, "researchAll", %{level: 0}, now)
      {:ok, player, [city], []} = Pg.state(id, now)
      assert city.fields == []
      assert player.research == %{}

      assert {:ok, _} = Pg.cheat(id, target, "resetCity", %{}, now)
      {:ok, _, [city], []} = Pg.state(id, now)

      assert Enum.sort_by(city.buildings, & &1.slot) == [
               %{type: "townhall", level: 1, slot: "townhall"},
               %{type: "walls", level: 1, slot: "walls"}
             ]

      assert city.troops == %{}
    end
  end
end
