defmodule Age3.Data do
  # Building costs, build times and requirements. priv/data/buildings.json is a copy of
  # packages/core/src/data/buildings.json: npm run sync-data at the repo root keeps them equal, and a web
  # test fails if they differ. So the client shows exactly what the server charges.
  #
  # The file is read once at compile time and baked into this module; @external_resource makes mix recompile
  # the module whenever the file changes.
  @moduledoc false

  @path Path.expand("../../priv/data/buildings.json", __DIR__)
  @external_resource @path
  @data @path |> File.read!() |> Jason.decode!()

  @doc "The highest level any building can reach."
  def max_level, do: @data["maxLevel"]

  @doc ~s(Every building type, e.g. "cottage" or "farm".)
  def building_types, do: Map.keys(@data["buildings"])

  @doc ~s(One building's spec: "area", "multiple", "requires" and "levels", or nil for an unknown type.)
  def building(type), do: @data["buildings"][type]

  @doc ~s(Cost and time to reach level: %{"cost" => %{"food" => ...}, "seconds" => ...}, or nil.)
  def level(type, level) when is_integer(level) and level >= 1 do
    case building(type) do
      %{"levels" => levels} -> Enum.at(levels, level - 1)
      nil -> nil
    end
  end

  def level(_type, _level), do: nil
end
