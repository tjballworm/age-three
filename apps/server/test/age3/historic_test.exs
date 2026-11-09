defmodule Age3.HistoricTest do
  use ExUnit.Case, async: true

  alias Age3.{Data, Historic, Npc, Pvp, Titles}

  test "a historic city tile is a target" do
    assert Pvp.target(nil, %{kind: "historic", level: 14}, "me") == {:historic, 14}
  end

  test "each city holds one type of every either/or slot, its own for good, and the shared forts and resources" do
    for level <- [12, 14, 16, 18], {x, y} <- [{9, 9}, {27, 9}, {33, 33}, {0, 0}] do
      hc = Historic.full(x, y, level)
      spec = Data.historic(level)
      assert hc == Historic.full(x, y, level)
      assert hc["forts"] == spec["forts"] and hc["resources"] == spec["resources"]
      assert Enum.sum(Map.values(hc["troops"])) > 0
      # one type out of every slot
      assert map_size(hc["troops"]) == length(spec["garrison"])
    end

    # Lv 16 and 18 always hold cataphracts and catapults
    assert %{"cataphract" => 677_777, "catapult" => 91_500, "warrior" => 7_000_000} =
             Historic.full(1, 2, 16)["troops"]

    # a Lv 12 that holds ballistae has as many as its cavalry
    picks = for x <- 0..200, do: Historic.full(x, 0, 12)["troops"]
    assert Enum.any?(picks, &(&1["ballista"] == 108_444))
    assert Enum.any?(picks, &(&1["catapult"] == 14_640))
    assert Enum.any?(picks, &Map.has_key?(&1, "sword")) and Enum.any?(picks, &Map.has_key?(&1, "pike"))
    assert Historic.full(0, 0, 11) == nil
  end

  test "fights with research 10, walls 10 and its ruler; refills over a day" do
    hc = Historic.full(9, 9, 12)
    {defender, forts, settings} = Historic.battle(hc, 12)
    assert defender.tech.archery == 10 and settings.walls == 10 and settings.npc
    assert %{level: 100, attack: 635, intelligence: 335, leadership: 99_999} = defender.hero
    assert forts == hc["forts"]

    empty = %{
      troops: Map.new(hc["troops"], fn {k, _} -> {k, 0} end),
      forts: Map.new(hc["forts"], fn {k, _} -> {k, 0} end),
      resources: Map.new(hc["resources"], fn {k, _} -> {k, 0} end),
      updated_at_ms: 0
    }

    half = Npc.current(empty, hc, 43_200_000, Historic.regen_seconds())
    assert half["troops"]["warrior"] == 560_000
    assert Npc.current(empty, hc, 86_400_000, Historic.regen_seconds()) == hc
  end

  test "medals for killing at least 5% of the garrison, won or lost: Justice and Nation" do
    full = %{"troops" => %{"warrior" => 1000}}
    killed = fn n -> %{defender: %{troops: [%{type: "warrior", lost: n}]}} end
    assert Historic.medals?(full, killed.(50))
    refute Historic.medals?(full, killed.(49))
    assert Titles.roll_historic(fn -> 0.0 end) == %{"justice" => 1, "nation" => 1}
    assert Titles.roll_historic(fn -> 0.35 end) == %{"justice" => 1}
    assert Titles.roll_historic(fn -> 0.5 end) == %{}
  end

  test "the garrison's either/or types are picked again every day" do
    days = for d <- 0..20, do: Historic.full(9, 9, 12, d)["troops"]
    assert length(Enum.uniq(days)) > 1
  end

  test "loyalty climbs back a point every 3 minutes and is full after the daily reset; 3 a win, capture at 0" do
    day = 86_400_000
    assert Historic.loyalty(10, day, day + 179_999) == 10
    assert Historic.loyalty(10, day, day + 180_000) == 11
    assert Historic.loyalty(99, day, day + 3_600_000) == 100
    assert Historic.loyalty(0, 2 * day - 1, 2 * day) == 100
    assert Historic.after_win(10, 1) == %{loyalty: 7, captured: false}
    assert Historic.after_win(2, 1) == %{loyalty: 0, captured: false}
    assert Historic.after_win(0, 9) == %{loyalty: 0, captured: true}
    assert Historic.after_win(0, 10) == %{loyalty: 0, captured: false}
  end

  test "rally spot bonus, policies a day and draft areas by level" do
    assert Enum.map([nil, 12, 14, 16, 18], &Historic.rally_multiplier/1) == [1, 1.25, 1.5, 2.0, 3.0]
    assert Enum.map([12, 14, 16, 18], &Historic.policies_a_day/1) == [4, 6, 8, 10]
    assert Historic.policies_left(12, 3, 5, 5 * 86_400_000) == 1
    assert Historic.policies_left(12, 3, 4, 5 * 86_400_000) == 4

    assert Historic.in_range?(12, {9, 9}, {18, 0})
    refute Historic.in_range?(12, {9, 9}, {19, 9})
    # the map wraps
    assert Historic.in_range?(12, {791, 27}, {0, 30})
    assert Historic.in_range?(14, {33, 33}, {66, 0})
    refute Historic.in_range?(14, {33, 33}, {67, 33})
    assert Historic.in_range?(16, {100, 100}, {0, 199})
    refute Historic.in_range?(16, {100, 100}, {200, 100})
    assert Historic.in_range?(18, {0, 0}, {400, 400})
  end

  test "what each policy takes" do
    amounts = %{"gold" => 1000.7, "food" => 500, "lumber" => 9}
    troops = %{"archer" => 1000, "warrior" => 10}
    assert Historic.take("tax", amounts, 0, troops)["resources"] == %{"gold" => 300}
    assert Historic.take("food", amounts, 0, troops)["resources"] == %{"food" => 100}
    assert Historic.take("population", amounts, 901.5, troops)["people"] == 450
    assert Historic.take("draft", amounts, 0, troops)["troops"] == %{"archer" => 50}
    assert Historic.take("disarm", amounts, 0, troops)["troops"] == %{"archer" => 100}
    assert Historic.take("draft", amounts, 0, %{})["troops"] == %{}
  end

  test "names as the map shows them" do
    assert Historic.name(0, 0) == "Atlantis"
    assert Historic.name(100, 100) == "Washington D.C."
    assert Historic.name(700, 700) == "Islamabad"
    assert Historic.name(27, 9) == "Historic City"
  end
end
