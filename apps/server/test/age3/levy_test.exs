defmodule Age3.LevyTest do
  use ExUnit.Case, async: true

  alias Age3.Levy

  test "each levy takes the wiki's share of the people there now, rounded down" do
    assert Levy.amount("gold", 1234.9) == 123
    assert Levy.amount("food", 1234.9) == 1234
    assert Levy.amount("lumber", 1234) == 1234
    assert Levy.amount("stone", 1235) == 617
    assert Levy.amount("iron", 1235) == 494
  end

  test "once every 15 minutes per city" do
    assert {:ok, 100} = Levy.check("gold", nil, 0, 1000)
    assert {:ok, 1000} = Levy.check("food", 0, 900_000, 1000)
    assert {:error, "levy_cooldown"} = Levy.check("food", 0, 899_999, 1000)
    assert {:error, "bad_message"} = Levy.check("gems", nil, 0, 1000)
  end
end
