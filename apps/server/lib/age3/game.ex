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

  @doc "A new player's first city starts with these resources: Record<ResourceType, ResourceStock>."
  def starter_resources do
    stock = fn amount, per_hour -> %{"amount" => amount, "perHour" => per_hour, "cap" => 100_000} end

    %{
      "gold" => stock.(5_000, 100),
      "food" => stock.(10_000, 200),
      "lumber" => stock.(10_000, 200),
      "stone" => stock.(10_000, 200),
      "iron" => stock.(5_000, 100)
    }
  end

  def starter_population, do: %{"current" => 100, "max" => 500, "idle" => 100}
end
