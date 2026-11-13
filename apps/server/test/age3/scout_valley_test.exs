defmodule Age3.ScoutValleyTest do
  use ExUnit.Case, async: true

  alias Age3.{Economy, March, Scout, Valley}

  describe "Scout" do
    test "level: min(Informatics, Beacon Tower) plus up to 2 for the hero; 0 without either" do
      assert Scout.level(5, 3, nil) == 3
      assert Scout.level(5, 3, 30) == 4
      assert Scout.level(5, 3, 99) == 5
      assert Scout.level(0, 10, 99) == 0
      assert Scout.level(4, 0, 99) == 0
    end

    test "outcome: 10 scouts per level, flats always, cities with open gates need more scouts than the defenders" do
      assert Scout.outcome(3, 50, {:level, 5}) == :ok
      assert Scout.outcome(3, 49, {:level, 5}) == {:error, "too_few_scouts"}
      assert Scout.outcome(0, 500, {:level, 1}) == {:error, "no_informatics"}
      assert Scout.outcome(1, 1, :flat) == :ok
      assert Scout.outcome(1, 1, {:city, nil}) == :ok
      assert Scout.outcome(1, 11, {:city, 10}) == :ok
      assert Scout.outcome(1, 10, {:city, 10}) == {:error, "scouts_beaten"}
    end

    test "detail and the counts it shows" do
      assert Scout.detail(5, 5) == :exact
      assert Scout.detail(3, 5) == :approx
      assert Scout.detail(2, 5) == :basic
      assert Scout.shown(12_345, :approx) == 12_000
      assert Scout.shown(98, :approx) == 98
      assert Scout.shown(12_345, :exact) == 12_345
      assert Scout.shown(12_345, :basic) == nil

      what = %{"troops" => %{"warrior" => 1234, "pike" => 0}, "research" => %{"x" => 1}, "buildings" => [1]}
      assert %{"troops" => %{"warrior" => nil}} = r = Scout.report(what, :basic)
      refute Map.has_key?(r, "buildings")
      assert %{"troops" => %{"warrior" => 1200}, "buildings" => [1]} = r = Scout.report(what, :approx)
      refute Map.has_key?(r, "research")
      assert %{"research" => %{"x" => 1}} = Scout.report(what, :exact)
    end
  end

  describe "Valley" do
    test "bonuses add up per resource from the wiki table" do
      assert Valley.bonus("lake", 10) == 35
      assert Valley.bonus("grassland", 1) == 3

      assert Valley.bonuses([
               %{terrain: "lake", level: 1},
               %{terrain: "swamp", level: 2},
               %{terrain: "hill", level: 3}
             ]) ==
               %{"food" => 15, "iron" => 9}
    end

    test "a valley bonus raises what the fields make, like research" do
      farm = %{type: "farm", level: 3, slot: "f0"}
      plain = Economy.rates([farm], 0)["food"]
      boosted = Economy.rates([farm], 0, %{}, %{}, 0, nil, %{"food" => 35})["food"]
      made = Age3.Data.level("farm", 3)["perHour"]
      assert boosted - plain == div(made * 135, 100) - made
    end
  end

  describe "March missions" do
    test "targets per mission" do
      mine = %{player_id: "me"}
      theirs = %{player_id: "them"}
      valley = %{kind: "valley", level: 3}
      flat = %{kind: "flat", level: 0}

      assert March.target("attack", theirs, flat, "me") == {:city, theirs}
      assert March.target("attack", mine, flat, "me") == {:error, "own_city"}
      assert March.target("transport", mine, flat, "me") == {:city, mine}
      assert March.target("reinforce", theirs, flat, "me") == {:city, theirs}
      assert March.target("attack", nil, valley, "me") == {:valley, 3}
      assert March.target("attack", nil, flat, "me") == {:error, "bad_target"}
      assert March.target("scout", nil, flat, "me") == {:flat, 0}
      assert March.target("found", nil, flat, "me") == {:flat, 0}
      assert March.target("found", nil, valley, "me") == {:error, "bad_target"}
      assert March.target("transport", nil, valley, "me") == {:error, "bad_target"}
    end

    test "valley terrain matches the TypeScript map (packages/core/src/rules/scout.test.ts)" do
      assert Enum.map([{0, 0}, {1, 2}, {100, 250}, {799, 799}, {33, 412}], fn {x, y} ->
               Age3.World.terrain(x, y)
             end) ==
               ~w(hill swamp swamp desert swamp)
    end

    test "relief station speeds" do
      assert Enum.map(0..10, &March.relief/1) == [1, 2, 2, 2, 3, 4, 4, 4, 5, 5, 6]
    end
  end

  describe "Beacon" do
    @march %{
      id: "m1",
      mission: "attack",
      arrives_at: 5000,
      lord: "Raider",
      from: %{x: 1, y: 2, name: "Raid Town"},
      troops: %{"cavalry" => 12_345, "scout" => 0},
      hero_level: 30,
      research: %{"archery" => 4}
    }

    test "each Beacon Tower level shows a little more of an incoming march" do
      assert Age3.Beacon.seen(0, @march) == nil
      assert Age3.Beacon.seen(1, @march) == %{id: "m1"}
      assert Age3.Beacon.seen(3, @march) == %{id: "m1", mission: "attack", arrivesAt: 5000}
      assert %{from: "Raider", fromCity: %{x: 1}, troops: %{"cavalry" => nil}} = Age3.Beacon.seen(6, @march)
      assert Age3.Beacon.seen(7, @march).troops == %{"cavalry" => "Giga"}
      assert Age3.Beacon.seen(8, @march).troops == %{"cavalry" => 12_345}
      refute Map.has_key?(Age3.Beacon.seen(8, @march), :heroLevel)
      assert %{heroLevel: 30, research: %{"archery" => 4}} = Age3.Beacon.seen(10, @march)
    end

    test "troop words for rough numbers" do
      words =
        for n <- [
              1,
              24,
              25,
              49,
              50,
              99,
              100,
              249,
              250,
              499,
              500,
              999,
              1000,
              2499,
              2500,
              4999,
              5000,
              10_000,
              10_001
            ],
            do: Age3.Beacon.troop_word(n)

      assert words ==
               ~w(Few Few Pack Pack Lots Lots Horde Horde Throng Throng Swarm Swarm Zounds Zounds Legion Legion Bulk Bulk Giga)
    end
  end
end
