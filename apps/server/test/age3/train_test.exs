defmodule Age3.TrainTest do
  use ExUnit.Case, async: true
  alias Age3.{Data, Train}

  # Town Hall, a Barracks on plot 4 and an Academy, all at level n
  defp town(n),
    do:
      for(
        {slot, type} <- [{"townhall", "townhall"}, {"4", "barracks"}, {"0", "academy"}],
        do: %{slot: slot, type: type, level: n}
      )

  defp rich,
    do: Map.new(~w(gold food lumber stone iron), &{&1, %{"amount" => 1.0e9, "perHour" => 0, "cap" => 0}})

  defp check(buildings, research, count, opts \\ []) do
    Train.check(
      buildings,
      research,
      opts[:resources] || rich(),
      opts[:idle] || 1.0e9,
      opts[:slot] || "4",
      opts[:troop] || "warrior",
      count,
      opts[:queued] || 0
    )
  end

  test "has the 12 troops of the battle calculator, each with a cost, a time and a Barracks level" do
    assert Enum.sort(Data.troop_ids()) ==
             Enum.sort(
               ~w(worker warrior scout pike sword archer cavalry cataphract transporter ballista ram catapult)
             )

    for id <- Data.troop_ids() do
      %{
        "cost" => cost,
        "seconds" => s,
        "population" => pop,
        "upkeep" => up,
        "requires" => %{"barracks" => lv}
      } =
        Data.troop(id)

      assert Map.keys(cost) |> Enum.sort() == ~w(food gold iron lumber stone)
      assert s > 0 and pop > 0 and up > 0 and lv in 1..10
    end
  end

  test "a batch costs count times one troop, takes their population, and count times the time" do
    assert {:ok, plan} = check(town(1), %{}, 100)
    assert plan.cost == %{"food" => 8000, "lumber" => 10_000, "stone" => 0, "iron" => 5000, "gold" => 0}
    assert %{troop: "warrior", count: 100, population: 100, seconds: 2400} = plan
  end

  test "Military Science trains 10% faster per level, only up to the city's Academy level" do
    assert {:ok, %{seconds: 1944}} = check(town(2), %{"militaryScience" => 2}, 100)
    assert {:ok, %{seconds: 2160}} = check(town(1), %{"militaryScience" => 2}, 100)
    assert Train.seconds("warrior", 1, %{"militaryScience" => 10}) == 8
    assert Train.seconds("worker", 1, %{"militaryScience" => 100}) == 1
  end

  test "Metal Casting also trains siege engines 10% faster per level, nothing else" do
    research = %{"militaryScience" => 1, "metalCasting" => 2}
    assert Train.seconds("catapult", 1, research) == round(6000 * :math.pow(0.9, 3))
    assert Train.seconds("ballista", 1, research) == round(3000 * :math.pow(0.9, 3))
    assert Train.seconds("ram", 1, research) == round(4500 * :math.pow(0.9, 3))
    assert Train.seconds("transporter", 1, research) == 900
  end

  test "the Barracks' own level unlocks troops" do
    # Swordsmen need a Barracks Lv3 (and Iron Working)
    research = %{"ironWorking" => 1}
    assert {:error, "requirement_not_met"} = check(town(2), research, 1, troop: "sword")
    assert {:ok, _} = check(town(3), research, 1, troop: "sword")

    # a second, lower Barracks doesn't train them
    low = [%{slot: "5", type: "barracks", level: 1} | town(3)]
    assert {:error, "requirement_not_met"} = check(low, research, 1, troop: "sword", slot: "5")
  end

  test "troops need their research, counted up to the city's Academy level" do
    assert {:error, "requirement_not_met"} = check(town(2), %{}, 1, troop: "pike")
    assert {:ok, _} = check(town(2), %{"militaryTradition" => 1}, 1, troop: "pike")

    no_academy = Enum.reject(town(2), &(&1.type == "academy"))
    assert {:error, "requirement_not_met"} = check(no_academy, %{"militaryTradition" => 1}, 1, troop: "pike")

    # Cavalry needs Horseback Riding 1 and a Barracks Lv5; a Lv5 Academy counts HBR 5 as 5
    assert {:ok, _} = check(town(5), %{"horsebackRiding" => 5}, 1, troop: "cavalry")
  end

  test "a Barracks trains one batch and keeps as many waiting as its level" do
    assert {:ok, _} = check(town(2), %{}, 1, queued: 2)
    assert {:error, "train_queue_full"} = check(town(2), %{}, 1, queued: 3)
  end

  test "needs resources and idle population" do
    poor = Map.new(~w(gold food lumber stone iron), &{&1, %{"amount" => 100, "perHour" => 0, "cap" => 0}})
    assert {:error, "not_enough_resources"} = check(town(1), %{}, 10, resources: poor)
    # archers take 2 people each
    town = town(4)
    assert {:error, "not_enough_population"} = check(town, %{"archery" => 1}, 10, troop: "archer", idle: 19.5)
    assert {:ok, %{population: 20}} = check(town, %{"archery" => 1}, 10, troop: "archer", idle: 20)
  end

  test "only in a Barracks, with a sensible count and a known troop" do
    assert {:error, "bad_slot"} = check(town(1), %{}, 1, slot: "0")
    assert {:error, "bad_slot"} = check(town(1), %{}, 1, slot: "9")
    assert {:error, "bad_message"} = check(town(1), %{}, 0)
    assert {:error, "bad_message"} = check(town(1), %{}, 2_000_000)
    assert {:error, "bad_message"} = check(town(1), %{}, 1, troop: "dragon")
  end

  test "upkeep and adding troops" do
    assert Train.upkeep(%{}) == 0
    assert Train.upkeep(nil) == 0
    assert Train.upkeep(%{"warrior" => 100_000, "catapult" => 2_000}) == 100 + 250
    # thousandths round up to whole food: any army eats at least 1
    assert Train.upkeep(%{"warrior" => 1}) == 1
    assert Train.upkeep(%{"warrior" => 1000}) == 1
    assert Train.upkeep(%{"warrior" => 1001}) == 2
    assert Train.upkeep(%{"warrior" => 300, "scout" => 300, "pike" => 300}) == 2
    assert Train.add(%{"warrior" => 5}, "warrior", 10) == %{"warrior" => 15}
    assert Train.add(%{}, "scout", 3) == %{"scout" => 3}
  end
end
