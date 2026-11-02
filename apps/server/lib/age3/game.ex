defmodule Age3.Game do
  # Game rules and starting values that aren't database access (like internal/game).
  @moduledoc false

  @doc "The map is world_size x world_size tiles and wraps. Matches WORLD_SIZE in packages/core."
  def world_size, do: 800

  @doc """
  True where the map has a historic city, so no player city is placed there.
  Matches historicCityAt in packages/core/src/world/states.ts: Atlantis at (0, 0), and in every
  200 x 200 state the capital at local (100, 100), Lv 14 every 66 from 33 and Lv 12 every 18 from 9,
  none at local (99, 99).
  """
  def historic_city?(0, 0), do: true

  def historic_city?(x, y) do
    lx = rem(x, 200)
    ly = rem(y, 200)

    cond do
      lx == 100 and ly == 100 -> true
      lx == 99 and ly == 99 -> false
      on_grid?(lx, 33, 66) and on_grid?(ly, 33, 66) -> true
      on_grid?(lx, 9, 18) and on_grid?(ly, 9, 18) -> true
      true -> false
    end
  end

  defp on_grid?(v, start, step), do: v >= start and rem(v - start, step) == 0

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
