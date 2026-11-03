defmodule Age3.Game do
  # Game rules and starting values that aren't database access (like internal/game).
  @moduledoc false

  @doc "The map is world_size x world_size tiles and wraps. Matches WORLD_SIZE in packages/core."
  def world_size, do: 800

  @doc "The seed the world map is generated from. Matches WORLD_SEED in apps/web/src/state/world.ts."
  def world_seed, do: 1

  @doc "True where the map has a historic city, so no player city is placed there."
  def historic_city?(x, y), do: historic_level(x, y) != nil

  @doc """
  The level of the historic city at (x, y), or nil. Matches historicCityAt in packages/core/src/world/states.ts
  (see there for the sources): Atlantis (Lv 18) at (0, 0); a capital (Lv 16) at the centre of every 200 x 200 state;
  Lv 14 every 66 from (33, 33) across the whole map, except the middle of each state's nine and two spots empty on
  the live game; Lv 12 every 18 from (9, 9), except within 9 tiles (on both axes) of a bigger historic city.
  """
  def historic_level(0, 0), do: 18

  def historic_level(x, y) do
    cond do
      capital?(x, y) -> 16
      lv14?(x, y) -> 14
      on_grid?(x, 9, 18, 791) and on_grid?(y, 9, 18, 791) and not near_bigger_city?(x, y) -> 12
      true -> nil
    end
  end

  @empty_lv14 [{693, 759}, {759, 759}]
  @lv12_clearance 9

  defp capital?(x, y), do: rem(x, 200) == 100 and rem(y, 200) == 100

  # On the 66 grid, not the middle of its state (the one spot also on the 18 grid), not empty on the live game.
  defp lv14?(x, y) do
    on_grid?(x, 33, 66, 759) and on_grid?(y, 33, 66, 759) and
      not (rem(x - 9, 18) == 0 and rem(y - 9, 18) == 0) and
      {x, y} not in @empty_lv14
  end

  defp near_bigger_city?(x, y) do
    near? = fn a, b -> abs(a - b) <= @lv12_clearance end
    cx = nearest(x, 100, 200)
    cy = nearest(y, 100, 200)
    # Lv 14 points are 66 apart, so at most one is within 9 on each axis.
    hx = nearest(x, 33, 66)
    hy = nearest(y, 33, 66)

    (near?.(x, 0) and near?.(y, 0)) or
      (near?.(x, cx) and near?.(y, cy)) or
      (near?.(x, hx) and near?.(y, hy) and lv14?(hx, hy))
  end

  defp on_grid?(v, start, step, last), do: v >= start and v <= last and rem(v - start, step) == 0

  # The grid point nearest v, rounding halves up like JavaScript's Math.round (v >= 0 here, so no negatives).
  defp nearest(v, start, step), do: start + floor((v - start) / step + 0.5) * step

  @doc """
  A new player's first city starts with these resources: Record<ResourceType, ResourceStock>. Its Town Hall and
  walls make nothing, so the rates are the base ones plus taxes at the starting 10%.
  """
  def starter_resources do
    rates = Age3.Economy.rates([], 10)
    cap = Age3.Economy.cap([])
    stock = fn name, amount -> %{"amount" => amount, "perHour" => rates[name], "cap" => cap} end

    %{
      "gold" => stock.("gold", 5_000),
      "food" => stock.("food", 10_000),
      "lumber" => stock.("lumber", 10_000),
      "stone" => stock.("stone", 10_000),
      "iron" => stock.("iron", 5_000)
    }
  end

  def starter_population, do: Age3.Economy.population([])
end
