defmodule Age3.GameTest do
  use ExUnit.Case, async: true

  alias Age3.Game

  test "historic city spots match packages/core" do
    assert Game.historic_level(0, 0) == 18
    assert Game.historic_level(700, 300) == 16
    # the guide's Lv 14s round Carinthia's capital (700, 500); the middle spot (693, 495) is empty
    for x <- [627, 693, 759], y <- [429, 495, 561], {x, y} != {693, 495} do
      assert Game.historic_level(x, y) == 14
    end

    refute Game.historic_city?(693, 495)
    refute Game.historic_city?(693, 759)
    assert Game.historic_level(27, 9) == 12
    # Lv 12 spots right by a bigger historic city stay empty
    refute Game.historic_city?(9, 9)
    refute Game.historic_city?(27, 27)
    refute Game.historic_city?(99, 99)
    refute Game.historic_city?(10, 9)
  end

  test "the map has Atlantis, 16 capitals, 126 Lv 14 and 1,793 Lv 12 historic cities" do
    counts =
      for x <- 0..799, y <- 0..799, level = Game.historic_level(x, y), reduce: %{} do
        acc -> Map.update(acc, level, 1, &(&1 + 1))
      end

    assert counts == %{18 => 1, 16 => 16, 14 => 126, 12 => 1793}
  end
end
