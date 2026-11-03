defmodule Age3.PvpTest do
  use ExUnit.Case, async: true

  alias Age3.Pvp

  test "what a march attacks: someone else's city, an NPC, or nothing" do
    city = %{player_id: "p2", name: "Town"}
    assert {:city, ^city} = Pvp.target(city, %{kind: "flat", level: 0}, "p1")
    assert {:error, "own_city"} = Pvp.target(city, %{kind: "flat", level: 0}, "p2")
    assert {:npc, 3} = Pvp.target(nil, %{kind: "npc", level: 3}, "p1")
    assert {:error, "bad_target"} = Pvp.target(nil, %{kind: "valley", level: 3}, "p1")
  end

  test "a closed gate opens by itself at loyalty 5" do
    assert Pvp.gate_open?(true, 100)
    refute Pvp.gate_open?(false, 6)
    assert Pvp.gate_open?(false, 5)
  end

  test "warehouses protect food, lumber, stone and iron, less 3% a Privateering level; gold never" do
    held = Age3.Data.level("warehouse", 2)["capacity"]
    buildings = [%{type: "warehouse", level: 2}]
    amounts = %{"gold" => 500.7, "food" => held + 100.9, "iron" => 10}
    assert Pvp.plunderable(amounts, buildings, %{}, 0) == %{"gold" => 500, "food" => 100, "iron" => 0}

    assert Pvp.plunderable(amounts, buildings, %{}, 10)["food"] ==
             trunc(held + 100.9 - held * :math.pow(0.97, 10))
  end

  test "a lost defence takes 3 loyalty and adds 2 grievance; a win at 0 captures, under the 10-city cap" do
    assert %{loyalty: 97, grievance: 2, captured: false} = Pvp.after_loss(100, 0, 1)
    assert %{loyalty: 0, captured: false} = Pvp.after_loss(2, 0, 1)
    assert %{loyalty: 0, captured: true} = Pvp.after_loss(0, 0, 9)
    assert %{captured: false} = Pvp.after_loss(0, 0, 10)
  end
end
