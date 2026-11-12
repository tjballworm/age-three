defmodule Age3.HealTest do
  use ExUnit.Case, async: true
  alias Age3.Heal

  defp gold(n), do: %{"gold" => %{"amount" => n, "perHour" => 0, "cap" => 0}}

  test "10% of each type lost is wounded, rounded down" do
    assert Heal.wounded(%{"warrior" => 1000, "cavalry" => 50, "archer" => 9}, %{
             "warrior" => 400,
             "cavalry" => 50
           }) ==
             %{"warrior" => 60}

    # the archers all died, but 10% of 9 rounds down to nobody
    assert Heal.wounded(%{"archer" => 19}, %{}) == %{"archer" => 1}
    assert Heal.wounded(%{}, %{}) == %{}
  end

  test "wounded add up" do
    assert Heal.add(%{"warrior" => 5}, %{"warrior" => 1, "pike" => 2}) == %{"warrior" => 6, "pike" => 2}
    assert Heal.total(%{"warrior" => 6, "pike" => 2}) == 8
  end

  test "healing costs gold: a quarter of the troop's training resources" do
    assert Heal.gold_each("warrior") == 58
    assert Heal.gold_each("cavalry") == 525
    assert Heal.gold_each("catapult") == 4800

    assert {:ok, %{cost: %{"gold" => 1105}}} =
             Heal.check(%{"warrior" => 20, "cavalry" => 5}, gold(2000), %{"warrior" => 10, "cavalry" => 1})

    assert {:error, "not_enough_resources"} = Heal.check(%{"warrior" => 20}, gold(100), %{"warrior" => 2})
    assert {:error, "not_enough_wounded"} = Heal.check(%{"warrior" => 20}, gold(1.0e9), %{"warrior" => 21})
    assert {:error, "not_enough_wounded"} = Heal.check(%{}, gold(1.0e9), %{"pike" => 1})
    assert {:error, "bad_message"} = Heal.check(%{"warrior" => 20}, gold(1.0e9), %{"warrior" => 0})
    assert {:error, "bad_message"} = Heal.check(%{"warrior" => 20}, gold(1.0e9), %{"dragon" => 1})
    assert {:error, "bad_message"} = Heal.check(%{"warrior" => 20}, gold(1.0e9), %{})
  end

  test "healed troops leave the wounded" do
    assert Heal.take(%{"warrior" => 20, "pike" => 3}, %{"warrior" => 5, "pike" => 3}) == %{"warrior" => 15}
  end
end
