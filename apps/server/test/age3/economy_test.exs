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
end
