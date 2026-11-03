defmodule Age3.CheatsTest do
  use ExUnit.Case, async: true

  alias Age3.Cheats

  test "parse checks each action's fields" do
    assert {:ok, %{amounts: %{"gold" => 5}}} = Cheats.parse("addResources", %{"amounts" => %{"gold" => 5}})
    assert {:error, _} = Cheats.parse("addResources", %{"amounts" => %{"gold" => 1.5}})
    assert {:error, _} = Cheats.parse("addResources", %{"amounts" => %{"gems" => 5}})
    assert {:ok, %{troops: %{"warrior" => -3}}} = Cheats.parse("addTroops", %{"troops" => %{"warrior" => -3}})
    assert {:error, _} = Cheats.parse("addTroops", %{"troops" => %{"dragon" => 3}})
    assert {:ok, %{amount: 0}} = Cheats.parse("setPopulation", %{"amount" => 0})
    assert {:error, _} = Cheats.parse("setPopulation", %{"amount" => -1})

    assert {:ok, %{slot: "4", type: "barracks", level: 3}} =
             Cheats.parse("setBuilding", %{"slot" => 4, "type" => "barracks", "level" => 3})

    assert {:ok, %{slot: "f2", type: nil, level: 0}} =
             Cheats.parse("setBuilding", %{"slot" => "f2", "level" => 0})

    assert {:error, _} = Cheats.parse("setBuilding", %{"slot" => 40, "level" => 1})
    assert {:error, _} = Cheats.parse("setBuilding", %{"slot" => 4, "type" => "castle", "level" => 1})
    assert {:error, _} = Cheats.parse("levelAll", %{"level" => 0})

    assert {:ok, %{tech: "archery", level: 10}} =
             Cheats.parse("setResearch", %{"tech" => "archery", "level" => 10})

    assert {:error, _} = Cheats.parse("setResearch", %{"tech" => "archery", "level" => 11})
    assert {:ok, %{}} = Cheats.parse("finishAll", %{})

    # setHero: only the fields sent; a new level starts at 0 exp
    assert {:ok, %{hero_id: "h", changes: [attack: 300]}} =
             Cheats.parse("setHero", %{"heroId" => "h", "attack" => 300})

    assert {:ok, %{changes: [exp: 0, level: 100, politics: 0]}} =
             Cheats.parse("setHero", %{"heroId" => "h", "level" => 100, "politics" => 0})

    assert {:error, _} = Cheats.parse("setHero", %{"heroId" => "h"})
    assert {:error, _} = Cheats.parse("setHero", %{"heroId" => "h", "level" => 0})
    assert {:error, _} = Cheats.parse("setHero", %{"heroId" => "h", "level" => 101})
    assert {:error, _} = Cheats.parse("setHero", %{"heroId" => "h", "attack" => 10_000})
    assert {:error, _} = Cheats.parse("setHero", %{"heroId" => "h", "attack" => -1})
    assert {:error, _} = Cheats.parse("setHero", %{"heroId" => "h", "attack" => 1.5})
    assert {:error, _} = Cheats.parse("setHero", %{"attack" => 5})
    assert {:ok, %{changes: [stars: 15]}} = Cheats.parse("setHero", %{"heroId" => "h", "stars" => 15})
    assert {:error, _} = Cheats.parse("setHero", %{"heroId" => "h", "stars" => 16})
    assert {:error, _} = Cheats.parse("launchNukes", %{})
  end

  test "resources and troops never go below zero" do
    res = %{"gold" => %{"amount" => 100.5, "perHour" => 10, "cap" => 1000}}
    assert %{"gold" => %{"amount" => 1100.5}} = Cheats.add_resources(res, %{"gold" => 1000})
    assert %{"gold" => %{"amount" => 0}} = Cheats.add_resources(res, %{"gold" => -5000})
    assert %{"gold" => %{"amount" => 1000}} = Cheats.fill_resources(res)

    assert Cheats.add_troops(%{"warrior" => 10}, %{"warrior" => -20, "archer" => 5}) == %{"archer" => 5}
  end

  test "place keeps buildings where they fit and one of a kind" do
    buildings = [
      %{slot: "townhall", type: "townhall", level: 1},
      %{slot: "3", type: "academy", level: 1},
      %{slot: "f0", type: "farm", level: 2}
    ]

    assert {:set, "academy"} = Cheats.place(buildings, "3", nil, 9)
    assert {:set, "cottage"} = Cheats.place(buildings, "5", "cottage", 4)
    assert {:set, "sawmill"} = Cheats.place(buildings, "f0", "sawmill", 1)
    assert {:remove} = Cheats.place(buildings, "f0", nil, 0)
    assert {:error, "bad_slot"} = Cheats.place(buildings, "townhall", nil, 0)
    assert {:error, "bad_slot"} = Cheats.place(buildings, "5", "farm", 1)
    assert {:error, "bad_slot"} = Cheats.place(buildings, "5", nil, 1)
    assert {:error, "requirement_not_met"} = Cheats.place(buildings, "6", "academy", 1)
  end

  test "research levels" do
    assert Cheats.set_research(%{"archery" => 2}, "archery", 0) == %{}
    assert Cheats.set_research(nil, "archery", 4) == %{"archery" => 4}
    assert map_size(Cheats.all_research(10)) == length(Age3.Data.tech_ids())
  end
end
