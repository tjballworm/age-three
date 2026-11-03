defmodule Age3.MarchTest do
  use ExUnit.Case, async: true

  alias Age3.{March, World}

  @rally [%{type: "rallyspot", level: 1}]

  # the nearest NPC city to {x, y} of this level, and one tile that isn't an NPC
  defp npc_near({x, y}, level) do
    for(d <- 1..60, dx <- -d..d, dy <- [-d, d], do: {x + dx, y + dy})
    |> Enum.find(fn {a, b} -> World.tile_at(a, b) == %{kind: "npc", level: level} end)
  end

  test "speed: the slowest troop sets the pace, 5x the original, Compass and Horseback Riding speed it up" do
    # warriors: 200 * 60 / 1000 = 12 tiles an hour, x5 = 60
    assert March.tiles_per_hour("warrior", %{}) == 60.0
    assert March.tiles_per_hour("warrior", %{"compass" => 10}) == 120.0
    assert March.tiles_per_hour("cavalry", %{"horsebackRiding" => 10}) == 450.0
    # 10 tiles at 60 an hour = 600 seconds; cavalry don't make warriors faster
    assert March.seconds({0, 0}, {6, 8}, %{"warrior" => 1, "cavalry" => 5}, %{}) == 600
    # the world wraps
    assert March.distance({1, 1}, {799, 1}) == 2.0
    assert March.seconds({0, 0}, {0, 0}, %{"scout" => 1}, %{}) == 1
  end

  test "food for the round trip, load with Logistics, and loot in proportion" do
    # there and back, an hour each way
    upkeep = Age3.Train.upkeep(%{"warrior" => 100})
    assert March.food(%{"warrior" => 100}, 3600) == ceil(upkeep * 2)
    load = Age3.Data.troop("warrior")["load"] * 100
    assert March.load(%{"warrior" => 100}, %{}) == load
    assert March.load(%{"warrior" => 100}, %{"logistics" => 5}) == floor(load * 1.5)

    assert March.loot(%{"food" => 100, "gold" => 50}, 1000) == %{"food" => 100, "gold" => 50}
    assert March.loot(%{"food" => 300, "gold" => 100}, 200) == %{"food" => 150, "gold" => 50}
    assert March.loot(%{"food" => 300}, 0) == %{"food" => 0}
  end

  test "check: Rally Spot, troop limit, troops at home, an idle hero, an NPC target and food" do
    home = {400, 400}
    target = npc_near(home, 1)
    troops = %{"warrior" => 20_000}
    idle = %{status: "idle"}
    send = %{"warrior" => 100}

    assert {:ok, plan} = March.check(@rally, %{}, troops, idle, home, target, 1_000_000, send)
    assert plan.troops == send and plan.level == 1
    assert plan.seconds == March.seconds(home, target, send, %{})
    assert plan.food == March.food(send, plan.seconds)

    assert {:error, "no_rally_spot"} = March.check([], %{}, troops, idle, home, target, 1_000_000, send)

    assert {:error, "too_many_troops"} =
             March.check(@rally, %{}, troops, idle, home, target, 1_000_000, %{"warrior" => 10_001})

    assert {:error, "not_enough_troops"} =
             March.check(@rally, %{}, %{"warrior" => 50}, idle, home, target, 1_000_000, send)

    assert {:error, "no_troops"} =
             March.check(@rally, %{}, troops, idle, home, target, 1_000_000, %{"warrior" => 0})

    assert {:error, "bad_message"} =
             March.check(@rally, %{}, troops, idle, home, target, 1_000_000, %{"dragon" => 1})

    assert {:error, "no_hero"} = March.check(@rally, %{}, troops, nil, home, target, 1_000_000, send)

    assert {:error, "hero_busy"} =
             March.check(@rally, %{}, troops, %{status: "mayor"}, home, target, 1_000_000, send)

    assert {:error, "bad_target"} = March.check(@rally, %{}, troops, idle, home, home, 1_000_000, send)
    assert {:error, "not_enough_resources"} = March.check(@rally, %{}, troops, idle, home, target, 0, send)
  end

  test "take" do
    assert March.take(%{"warrior" => 100, "pike" => 5}, %{"warrior" => 40}) == %{"warrior" => 60, "pike" => 5}
  end
end
