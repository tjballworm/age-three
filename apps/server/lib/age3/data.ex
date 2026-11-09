defmodule Age3.Data do
  # Building, research and troop costs, times and requirements. priv/data/buildings.json, research.json,
  # troops.json, npcs.json, historic-cities.json, medals.json and titles.json are copies of the files in
  # packages/core/src/data: npm run sync-data at the repo root keeps them equal, and a web test fails if they
  # differ. So the client shows exactly what the server charges.
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

  @troops_path Path.expand("../../priv/data/troops.json", __DIR__)
  @external_resource @troops_path
  @troops @troops_path |> File.read!() |> Jason.decode!()

  @npcs_path Path.expand("../../priv/data/npcs.json", __DIR__)
  @external_resource @npcs_path
  @npcs @npcs_path |> File.read!() |> Jason.decode!()

  @medals_path Path.expand("../../priv/data/medals.json", __DIR__)
  @external_resource @medals_path
  @medals @medals_path |> File.read!() |> Jason.decode!()

  @historic_path Path.expand("../../priv/data/historic-cities.json", __DIR__)
  @external_resource @historic_path
  @historic @historic_path |> File.read!() |> Jason.decode!()

  @titles_path Path.expand("../../priv/data/titles.json", __DIR__)
  @external_resource @titles_path
  @titles @titles_path |> File.read!() |> Jason.decode!()

  @doc "The nine medal ids, lowest first: cross ... nation."
  def medal_ids, do: Enum.map(@medals["medals"], & &1["id"])

  @doc "Chance of each medal for a full clear of an NPC of this level, e.g. %{\"cross\" => 0.225}; %{} outside 1-10."
  def npc_medal_drops(level) when is_integer(level) and level in 1..10,
    do: Enum.at(@medals["drops"]["npc"], level - 1)

  def npc_medal_drops(_level), do: %{}

  @doc "Chance of each medal for a qualifying battle against a historic city (any level), e.g. %{\"justice\" => 0.4}."
  def historic_medal_drops, do: @medals["drops"]["historic"]

  @doc "Ranks, lowest (civilian) first: maps with id, name, gold, townHall, medals and prestigeAward."
  def ranks, do: @titles["ranks"]

  @doc "Titles, lowest (civilian) first: maps with id, name, rank, gold, prestige, medals, prestigeAward, cities."
  def titles, do: @titles["titles"]

  @doc "Whether promoting to a title checks its prestige need (off while nothing earns prestige)."
  def title_checks_prestige?, do: @titles["checkPrestige"]

  @doc ~s(A full NPC city of this level: %{"troops", "forts", "resources"}, or nil.)
  def npc(level) when is_integer(level) and level in 1..10 do
    n = Enum.at(@npcs["npcs"], level - 1)
    %{"troops" => n["troops"], "forts" => n["fortifications"], "resources" => n["resources"]}
  end

  def npc(_level), do: nil

  @doc """
  A historic city of this level (12, 14, 16 or 18) from historic-cities.json, or nil: %{"ruler", "garrison",
  "walls", "research", "forts", "resources"}. garrison is the file's list of slots (%{"types", "count", "counts"}).
  """
  def historic(level) do
    case Enum.find(@historic["cities"], &(&1["level"] == level)) do
      nil ->
        nil

      c ->
        %{
          "ruler" => c["ruler"],
          "garrison" => c["garrison"],
          "walls" => @historic["walls"],
          "research" => @historic["research"],
          "forts" => @historic["fortifications"],
          "resources" => @historic["resources"]
        }
    end
  end

  @doc "Seconds an NPC takes to refill its garrison and fortifications, and its resources, from empty."
  def npc_regen_seconds, do: {@npcs["garrisonRegenSeconds"], @npcs["resourceRegenSeconds"]}

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

  @doc "The highest research level."
  def max_tech_level, do: @research["maxLevel"]

  @doc ~s(Cost, time and needs to research level: %{"cost", "seconds", "requires" => buildings, "research" => techs}.)
  def tech_level(id, level) when is_integer(level) and level >= 1 do
    case tech(id) do
      %{"levels" => levels} -> Enum.at(levels, level - 1)
      nil -> nil
    end
  end

  def tech_level(_id, _level), do: nil

  @doc ~s(Every troop type, e.g. "warrior" or "cavalry". The same ids as TROOPS in packages/core/src/combat.)
  def troop_ids, do: Map.keys(@troops["troops"])

  @doc ~s(One troop's spec: "name", "cost", "seconds", "population", "upkeep", "requires", "research", or nil.)
  def troop(id), do: @troops["troops"][id]
end
