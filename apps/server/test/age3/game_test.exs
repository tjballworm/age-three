defmodule Age3.GameTest do
  use ExUnit.Case, async: true

  alias Age3.Game

  test "historic city spots match packages/core" do
    assert Game.historic_city?(0, 0)
    assert Game.historic_city?(700, 300)
    assert Game.historic_city?(233, 365)
    assert Game.historic_city?(209, 389)
    refute Game.historic_city?(299, 299)
    refute Game.historic_city?(10, 9)
  end

  test "every state has 1 capital, 8 Lv 14 and 120 Lv 12 historic cities" do
    spots = for x <- 200..399, y <- 200..399, Game.historic_city?(x, y), do: {x, y}
    assert length(spots) == 129
  end
end
