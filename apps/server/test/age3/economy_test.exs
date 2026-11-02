defmodule Age3.EconomyTest do
  use ExUnit.Case, async: true
  alias Age3.Economy

  @hour 3_600_000

  defp stock(amount, per_hour, cap \\ 100_000), do: %{"amount" => amount, "perHour" => per_hour, "cap" => cap}

  defp food_after(stock, ms), do: Economy.settle(%{"food" => stock}, 0, ms)["food"]["amount"]

  test "grows by perHour over an hour" do
    assert_in_delta food_after(stock(1_000, 200), @hour), 1_200, 0.001
  end

  test "half an hour gives half the production" do
    assert_in_delta food_after(stock(1_000, 200), div(@hour, 2)), 1_100, 0.001
  end

  test "keeps fractions" do
    assert_in_delta food_after(stock(1_000, 200), 9_000), 1_000.5, 0.001
  end

  test "stops at the cap" do
    assert food_after(stock(99_900, 200), @hour) == 100_000
  end

  test "an amount already over the cap stays put" do
    assert food_after(stock(120_000, 200), @hour) == 120_000
  end

  test "a negative rate drains to zero, not below" do
    assert food_after(stock(100, -200), @hour) == 0
    assert_in_delta food_after(stock(1_000, -200), @hour), 800, 0.001
  end

  test "a clock going backwards changes nothing" do
    assert Economy.settle(%{"food" => stock(1_000, 200)}, @hour, 0)["food"]["amount"] == 1_000
  end

  test "settles every resource and leaves perHour and cap alone" do
    out = Economy.settle(%{"food" => stock(0, 100, 50), "gold" => stock(10, 0)}, 0, @hour)
    assert out == %{"food" => stock(50, 100, 50), "gold" => stock(10, 0)}
  end

  describe "production from buildings" do
    defp b(type, level), do: %{type: type, level: level}

    test "an empty city makes the base rates, plus gold from taxes" do
      assert Economy.rates([], 10) == %{
               "food" => 100,
               "lumber" => 100,
               "stone" => 100,
               "iron" => 100,
               "gold" => 110
             }
    end

    test "fields add to their resource, one rate per level" do
      rates = Economy.rates([b("farm", 1), b("farm", 2), b("sawmill", 1), b("townhall", 3)], 0)
      farm = fn level -> Age3.Data.level("farm", level)["perHour"] end
      assert rates["food"] == 100 + farm.(1) + farm.(2)
      assert rates["lumber"] == 100 + Age3.Data.level("sawmill", 1)["perHour"]
      assert rates["gold"] == 100
    end

    test "cottages raise population, and with it taxes" do
      cottage = Age3.Data.level("cottage", 2)["population"]
      assert %{"current" => pop, "max" => pop, "idle" => pop} = Economy.population([b("cottage", 2)])
      assert pop == 100 + cottage
      assert Economy.rates([b("cottage", 2)], 20)["gold"] == 100 + div(pop * 20, 100)
    end

    test "warehouses raise the cap" do
      assert Economy.cap([]) == 100_000

      assert Economy.cap([b("warehouse", 1), b("warehouse", 2)]) ==
               100_000 + Age3.Data.level("warehouse", 1)["capacity"] +
                 Age3.Data.level("warehouse", 2)["capacity"]
    end

    test "Agriculture, Lumbering, Masonry and Mining add 10% per level to their fields, not to the base" do
      farm = Age3.Data.level("farm", 3)["perHour"]
      rates = Economy.rates([b("farm", 3), b("academy", 5)], 0, %{"agriculture" => 2, "masonry" => 5})
      assert rates["food"] == 100 + div(farm * 120, 100)
      assert rates["stone"] == 100
    end

    test "research only counts up to the city's Academy level, and not at all without one" do
      farm = Age3.Data.level("farm", 3)["perHour"]
      research = %{"agriculture" => 5}
      assert Economy.rates([b("farm", 3), b("academy", 2)], 0, research)["food"] == 100 + div(farm * 120, 100)
      assert Economy.rates([b("farm", 3)], 0, research)["food"] == 100 + farm
    end

    test "Stockpile adds 10% per level to what warehouses hold" do
      held = Age3.Data.level("warehouse", 2)["capacity"]
      town = [b("warehouse", 2), b("academy", 6)]
      assert Economy.cap(town, %{"stockpile" => 3}) == 100_000 + div(held * 130, 100)
      assert Economy.cap([b("warehouse", 2)], %{"stockpile" => 3}) == 100_000 + held
      assert Economy.cap([], %{"stockpile" => 3}) == 100_000
    end

    test "troops eat food every hour, and taxes come from the population limit" do
      rates = Economy.rates([b("cottage", 1)], 10, %{}, %{"warrior" => 100, "cavalry" => 10})
      assert rates["food"] == 100 - 100 - 90
      assert rates["gold"] == 100 + div(Economy.max_population([b("cottage", 1)]) * 10, 100)
    end

    test "recalc changes perHour and cap, and keeps amounts" do
      out = Economy.recalc(%{"food" => stock(5, 1, 9)}, [b("farm", 1)], 10)
      assert out == %{"food" => stock(5, 100 + Age3.Data.level("farm", 1)["perHour"], 100_000)}
    end
  end

  describe "population" do
    test "people move back in at (100 - tax)% / 2 of the limit per hour, up to the limit" do
      pop = %{"current" => 100, "max" => 1000, "idle" => 100}
      # 10% tax: 45% of 1000 an hour
      assert %{"current" => 550.0, "idle" => 550.0, "max" => 1000} =
               Economy.settle_population(pop, 10, 0, 3_600_000)

      assert %{"current" => 1000} = Economy.settle_population(pop, 10, 0, 10 * 3_600_000)
      # nobody comes back at 100% tax, and time going backwards changes nothing
      assert %{"current" => 100} = Economy.settle_population(pop, 100, 0, 3_600_000)
      assert %{"current" => 100} = Economy.settle_population(pop, 10, 1000, 0)
    end

    test "take_population takes people out, and gives them back" do
      pop = %{"current" => 500, "max" => 1000, "idle" => 500}
      assert %{"current" => 400, "idle" => 400} = Economy.take_population(pop, 100)
      assert %{"current" => 600, "idle" => 600} = Economy.take_population(pop, -100)
    end
  end
end
