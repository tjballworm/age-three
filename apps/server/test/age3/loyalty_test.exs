defmodule Age3.LoyaltyTest do
  use ExUnit.Case, async: true

  alias Age3.Loyalty

  defp pop(current, max \\ 1000), do: %{"current" => current, "max" => max, "idle" => current}

  test "ticks fall on whole 6-minute marks" do
    assert Loyalty.next_tick(0) == 360_000
    assert Loyalty.next_tick(359_999) == 360_000
    assert Loyalty.next_tick(360_000) == 720_000
  end

  test "loyalty steps 1 a tick towards 100 - tax - grievance" do
    assert Loyalty.target(10, 0) == 90
    assert Loyalty.target(60, 50) == 0
    assert {99, _} = Loyalty.tick(100, pop(1000), 10, 0)
    assert {51, _} = Loyalty.tick(50, pop(500), 10, 20)
    assert {70, _} = Loyalty.tick(70, pop(700), 10, 20)
  end

  test "people move towards loyalty% of the limit at the wiki's rates" do
    # up 4.5% of the limit at 10% tax, not past the loyalty line
    assert {90, %{"current" => 545.0}} = Loyalty.tick(90, pop(500), 10, 0)
    assert {90, %{"current" => 900.0}} = Loyalty.tick(90, pop(880), 10, 0)
    # down 2.5% at 50% tax, and that can go past the line
    assert {59, %{"current" => 575.0}} = Loyalty.tick(60, pop(600), 50, 0)
    # 0% up at 100% tax, 0% down at 0% tax
    assert {49, %{"current" => 100.0}} = Loyalty.tick(50, pop(100), 100, 0)
    assert {_, %{"current" => 1000.0}} = Loyalty.tick(10, pop(1000), 0, 90)
  end

  test "comforting costs the population limit, once every 15 minutes" do
    assert {:ok, %{resource: "food", cost: 1000, loyalty: 5, grievance: -15, gain: %{}, people: 0}} =
             Loyalty.check_comfort("relief", nil, 0, pop(800), 1000)

    assert {:ok, %{resource: "gold", cost: 1000, loyalty: 25, grievance: -5}} =
             Loyalty.check_comfort("pray", 0, 900_000, pop(800), 5000)

    assert {:error, "comfort_cooldown"} = Loyalty.check_comfort("pray", 0, 899_999, pop(800), 5000)
    assert {:error, "not_enough_resources"} = Loyalty.check_comfort("relief", nil, 0, pop(800), 999)
    assert {:error, "bad_message"} = Loyalty.check_comfort("feast", nil, 0, pop(800), 1000)
    assert Loyalty.apply_change(90, 10, 25, -15) == {100, 0}
  end

  test "Blessing turns a tenth of the limit in gold into 10x the limit in food" do
    assert {:ok,
            %{resource: "gold", cost: 100, loyalty: 0, grievance: 0, gain: %{"food" => 10_000}, people: 0}} =
             Loyalty.check_comfort("bless", nil, 0, pop(800), 100)

    assert {:error, "not_enough_resources"} = Loyalty.check_comfort("bless", nil, 0, pop(800), 99)
  end

  test "Population Raising pays 10 food a person for a tenth more people, never past the limit" do
    assert {:ok, %{resource: "food", cost: 8000, gain: %{}, people: 80}} =
             Loyalty.check_comfort("raise", nil, 0, pop(800.7), 8000)

    assert {:ok, %{people: 5}} = Loyalty.check_comfort("raise", nil, 0, pop(995), 9950)
    assert {:ok, %{cost: 0, people: 1}} = Loyalty.check_comfort("raise", nil, 0, pop(0), 0)
    assert {:error, "population_full"} = Loyalty.check_comfort("raise", nil, 0, pop(1000), 100_000)
  end

  test "taxes come from the people there now, rounded down" do
    assert Loyalty.tax_gold(pop(999.9), 10) == 99
    assert Loyalty.tax_gold(pop(1000), 0) == 0
  end
end
