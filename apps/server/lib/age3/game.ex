defmodule Age3.Game do
  # Game rules and starting values that aren't database access (like internal/game).
  @moduledoc false

  @doc "The map is world_size x world_size tiles and wraps. Matches WORLD_SIZE in packages/core."
  def world_size, do: 100

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
