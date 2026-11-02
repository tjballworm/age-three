defmodule Age3.ResearchTest do
  use ExUnit.Case, async: true
  alias Age3.{Data, Research}

  # Town Hall, walls, an Academy and a Farm at level n
  defp town(n),
    do:
      for(
        {slot, type} <- [{"townhall", "townhall"}, {"walls", "walls"}, {"0", "academy"}, {"f0", "farm"}],
        do: %{slot: slot, type: type, level: n}
      )

  defp rich,
    do: Map.new(~w(gold food lumber stone iron), &{&1, %{"amount" => 1.0e9, "perHour" => 0, "cap" => 0}})

  defp poor, do: Map.new(~w(gold food lumber stone iron), &{&1, %{"amount" => 0, "perHour" => 0, "cap" => 0}})

  test "has 19 technologies, each with a cost, a time and an Academy level for every level" do
    assert length(Data.tech_ids()) == 19

    for id <- Data.tech_ids(), lv <- 1..10 do
      %{"cost" => cost, "seconds" => s, "requires" => %{"academy" => academy}} = Data.tech_level(id, lv)
      assert Map.keys(cost) |> Enum.sort() == ~w(food gold iron lumber stone)
      assert s > 0 and academy >= lv
    end

    assert Data.tech_level("agriculture", 11) == nil
    assert Data.tech("nope") == nil
  end

  test "researches the next level for the data file's cost and time" do
    assert {:ok, plan} = Research.check(town(1), %{}, rich(), "agriculture")
    assert %{tech: "agriculture", level: 1} = plan
    assert plan.cost == Data.tech_level("agriculture", 1)["cost"]
    assert plan.seconds == 400

    assert {:ok, %{level: 3}} = Research.check(town(3), %{"agriculture" => 2}, rich(), "agriculture")
  end

  test "needs an Academy" do
    no_academy = Enum.reject(town(1), &(&1.type == "academy"))
    assert {:error, "no_academy"} = Research.check(no_academy, %{}, rich(), "agriculture")
  end

  test "each level needs an Academy of that level, and the building the table names" do
    # Agriculture Lv2 needs Academy Lv2 and Farm Lv2
    assert {:error, "requirement_not_met"} =
             Research.check(town(1), %{"agriculture" => 1}, rich(), "agriculture")

    # Masonry is unlocked by Academy Lv2
    assert {:error, "requirement_not_met"} = Research.check(town(1), %{}, rich(), "masonry")
  end

  test "some techs need other research first" do
    # Mining needs Masonry Lv1 (and an Iron Mine of its level)
    town = [%{slot: "f1", type: "ironmine", level: 2} | town(2)]
    assert {:error, "requirement_not_met"} = Research.check(town, %{}, rich(), "mining")
    assert {:ok, %{level: 1}} = Research.check(town, %{"masonry" => 1}, rich(), "mining")
  end

  test "stops at the top level, refuses unknown techs, and checks resources" do
    assert {:error, "max_level"} = Research.check(town(10), %{"agriculture" => 10}, rich(), "agriculture")
    assert {:error, "bad_message"} = Research.check(town(1), %{}, rich(), "nope")
    assert {:error, "not_enough_resources"} = Research.check(town(1), %{}, poor(), "agriculture")
  end

  test "a city gets research up to its Academy's level, and none without an Academy" do
    research = %{"archery" => 10, "agriculture" => 3}
    assert Research.in_city(research, town(5)) == %{"archery" => 5, "agriculture" => 3}
    assert Research.in_city(research, [%{slot: "townhall", type: "townhall", level: 5}]) == %{}
  end

  test "Construction makes building 10% faster per level, compounding" do
    assert Research.build_seconds(1000, %{}) == 1000
    assert Research.build_seconds(1000, %{"construction" => 1}) == 900
    assert Research.build_seconds(1000, %{"construction" => 2}) == 810
    assert Research.build_seconds(60, %{"construction" => 10}) == 21
  end
end
