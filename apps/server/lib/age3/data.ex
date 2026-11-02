defmodule Age3.Data do
  # Building and research costs, times and requirements. priv/data/buildings.json and research.json are copies
  # of the files in packages/core/src/data: npm run sync-data at the repo root keeps them equal, and a web test
  # fails if they differ. So the client shows exactly what the server charges.
  #
  # The files are read once at compile time and baked into this module; @external_resource makes mix recompile
  # the module whenever they change.
  @moduledoc false

  @path Path.expand("../../priv/data/buildings.json", __DIR__)
  @external_resource @path
  @data @path |> File.read!() |> Jason.decode!()

  @research_path Path.expand("../../priv/data/research.json", __DIR__)
  @external_resource @research_path
  @research @research_path |> File.read!() |> Jason.decode!()

  @doc "The highest level any building can reach."
  def max_level, do: @data["maxLevel"]

  @doc "Builds with this long or less left can be finished for free (the Speedup button)."
  def free_speedup_ms, do: @data["freeSpeedupSeconds"] * 1000

  @doc ~s(What a city has before any buildings: %{"perHour" => %{"food" => ...}, "population" => ...}.)
  def base, do: @data["base"]

  @doc ~s(Every building type, e.g. "cottage" or "farm".)
  def building_types, do: Map.keys(@data["buildings"])

  @doc ~s(One building's spec: "area", "multiple" and "levels", or nil for an unknown type.)
  def building(type), do: @data["buildings"][type]

  @doc ~s(Cost, time and needs to reach level: %{"cost" => %{"food" => ...}, "seconds" => ..., "requires" => ...}, or nil.)
  def level(type, level) when is_integer(level) and level >= 1 do
    case building(type) do
      %{"levels" => levels} -> Enum.at(levels, level - 1)
      nil -> nil
    end
  end

  def level(_type, _level), do: nil

  @doc ~s(Every technology, e.g. "agriculture" or "militaryScience".)
  def tech_ids, do: Map.keys(@research["techs"])

  @doc ~s(One technology's spec: "name", "group", "effect", "levels" and so on, or nil for an unknown id.)
  def tech(id), do: @research["techs"][id]

  @doc ~s(Cost, time and needs to research level: %{"cost", "seconds", "requires" => buildings, "research" => techs}.)
  def tech_level(id, level) when is_integer(level) and level >= 1 do
    case tech(id) do
      %{"levels" => levels} -> Enum.at(levels, level - 1)
      nil -> nil
    end
  end

  def tech_level(_id, _level), do: nil
end
