defmodule Age3.LordTest do
  use ExUnit.Case, async: true

  alias Age3.{Lord, Npc, Pvp}

  test "names and lords match the map (generateWorld in packages/core)" do
    assert {Lord.name(12, 0), Lord.owner(12, 0)} == {"Galbel", "Selene"}
    assert {Lord.name(13, 0), Lord.owner(13, 0)} == {"Thrathrarin", "Brannoc"}
    assert {Lord.name(30, 0), Lord.owner(30, 0)} == {"Beldor", "Selene"}
  end

  test "a random garrison for each town, half to one and a half an NPC's, and walls full of archer towers" do
    for level <- 1..10, {x, y} <- [{12, 0}, {13, 0}, {30, 0}, {400, 517}] do
      town = Lord.full(x, y, level)
      npc = Npc.full(level)
      total = town["troops"] |> Map.values() |> Enum.sum()
      npc_total = npc["troops"] |> Map.values() |> Enum.sum()

      assert total >= div(npc_total, 2) - 6 and total <= npc_total * 3 / 2
      assert Enum.all?(Map.keys(town["troops"]), &(&1 in ~w(warrior pike sword archer cavalry cataphract)))
      if level < 5, do: refute(Map.has_key?(town["troops"], "cataphract"))
      assert Map.keys(town["forts"]) == ["tower"]
      assert town["resources"] == npc["resources"]
      # the same every time
      assert Lord.full(x, y, level) == town
    end

    assert Lord.full(12, 0, 1)["forts"] == %{"tower" => 333}
    assert Lord.full(12, 0, 10)["forts"] == %{"tower" => 18_333}
    refute Lord.full(12, 0, 3) == Lord.full(13, 0, 3)
    assert Lord.full(12, 0, 11) == nil
  end

  test "an empty lord's town tile is a target; a real player's city on it is still a player city" do
    assert Pvp.target(nil, %{kind: "city", level: 4}, "me") == {:lord, 4}
    assert {:city, _} = Pvp.target(%{player_id: "them"}, %{kind: "city", level: 4}, "me")
  end
end
