defmodule Age3.BuildTest do
  use ExUnit.Case, async: true
  alias Age3.{Build, Data}

  # a starter town: Town Hall and walls at Lv1
  @town [%{slot: "townhall", type: "townhall", level: 1}, %{slot: "walls", type: "walls", level: 1}]

  defp rich,
    do: Map.new(~w(gold food lumber stone iron), &{&1, %{"amount" => 1.0e9, "perHour" => 0, "cap" => 0}})

  defp poor, do: Map.new(~w(gold food lumber stone iron), &{&1, %{"amount" => 0, "perHour" => 0, "cap" => 0}})

  test "builds a cottage on an empty plot at Lv1, for the data file's cost and time" do
    assert {:ok, plan} = Build.check(@town, rich(), "3", "cottage")
    assert %{type: "cottage", level: 1} = plan
    assert plan.cost == Data.level("cottage", 1)["cost"]
    assert plan.seconds == Data.level("cottage", 1)["seconds"]
  end

  test "upgrades what stands on the slot, with or without naming its type" do
    town = [%{slot: "3", type: "cottage", level: 1}, %{slot: "townhall", type: "townhall", level: 2}]
    assert {:ok, %{type: "cottage", level: 2}} = Build.check(town, rich(), "3", nil)
    assert {:ok, %{type: "cottage", level: 2}} = Build.check(town, rich(), "3", "cottage")
    assert {:error, "bad_slot"} = Build.check(town, rich(), "3", "inn")
  end

  test "nothing goes above the Town Hall's level, except the Town Hall" do
    assert {:error, "requirement_not_met"} = Build.check(@town, rich(), "walls", nil)
    assert {:ok, %{type: "townhall", level: 2}} = Build.check(@town, rich(), "townhall", nil)
  end

  test "stops at the top level" do
    town = [%{slot: "townhall", type: "townhall", level: Data.max_level()}]
    assert {:error, "max_level"} = Build.check(town, rich(), "townhall", nil)
  end

  test "checks what a building needs first, and one-per-city limits" do
    assert {:error, "requirement_not_met"} = Build.check(@town, rich(), "0", "barracks")
    with_rally = [%{slot: "1", type: "rallyspot", level: 1} | @town]
    assert {:ok, _} = Build.check(with_rally, rich(), "0", "barracks")
    assert {:error, "requirement_not_met"} = Build.check(with_rally, rich(), "0", "rallyspot")
    # cottages may repeat
    assert {:ok, _} = Build.check([%{slot: "1", type: "cottage", level: 1} | @town], rich(), "0", "cottage")
  end

  test "each kind of building goes in its own place" do
    assert {:ok, %{type: "farm"}} = Build.check(@town, rich(), "f0", "farm")
    assert {:error, "bad_slot"} = Build.check(@town, rich(), "f0", "cottage")
    assert {:error, "bad_slot"} = Build.check(@town, rich(), "0", "farm")
    assert {:error, "bad_slot"} = Build.check(@town, rich(), "0", "townhall")
    assert {:error, "bad_slot"} = Build.check(@town, rich(), "32", "cottage")
    assert {:error, "bad_slot"} = Build.check(@town, rich(), "f13", "farm")
    assert {:error, "bad_slot"} = Build.check(@town, rich(), "0", "castle")
    assert {:error, "bad_slot"} = Build.check(@town, rich(), "0", nil)
  end

  test "needs the resources" do
    assert {:error, "not_enough_resources"} = Build.check(@town, poor(), "3", "cottage")
  end

  test "spend takes the cost off, and gives it back with sign -1" do
    cost = %{"food" => 100, "lumber" => 300, "stone" => 0, "iron" => 0, "gold" => 0}
    res = %{"food" => %{"amount" => 1000, "perHour" => 5, "cap" => 9}, "lumber" => %{"amount" => 500.5}}
    spent = Build.spend(res, cost)
    assert spent["food"] == %{"amount" => 900, "perHour" => 5, "cap" => 9}
    assert spent["lumber"]["amount"] == 200.5
    assert Build.spend(spent, cost, -1) == res
  end
end
