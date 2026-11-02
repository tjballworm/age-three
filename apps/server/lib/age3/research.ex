defmodule Age3.Research do
  # The Academy's rules, as pure functions (no database), like Age3.Build for construction.
  # A player's research levels are one map for all their cities (players.research, e.g. %{"agriculture" => 2});
  # each research runs in one city's Academy, one at a time per Academy. A city only gets research up to its own
  # Academy's level (in_city/2): Archery 10 counts as Archery 5 in a city with an Academy Lv5, and as nothing in a
  # city with no Academy.
  @moduledoc false

  alias Age3.{Build, Data}

  @doc """
  Can the player research the next level of tech in a city with these buildings? research is the player's
  levels, resources the city's settled resources. Each level needs an Academy of at least that level (and of the
  level that unlocks the tech), sometimes another building of that level (Agriculture Lv3 needs a Farm Lv3), and
  sometimes other research.

  Returns {:ok, %{tech, level, cost, seconds}} for the next level, or {:error, code}.
  """
  def check(buildings, research, resources, tech) do
    level = level_of(research, tech) + 1

    with %{} <- Data.tech(tech) || {:error, "bad_message"},
         :ok <- has_academy(buildings),
         %{"cost" => cost, "seconds" => seconds} = needs <-
           Data.tech_level(tech, level) || {:error, "max_level"},
         :ok <- requirements(buildings, research, needs),
         :ok <- Build.affordable(resources, cost) do
      {:ok, %{tech: tech, level: level, cost: cost, seconds: seconds}}
    end
  end

  @doc """
  The research levels that count in a city with these buildings: each capped at its Academy's level, so a city
  without an Academy gets none. Effects (production, storage, build time) and building requirements use this.
  """
  def in_city(research, buildings) do
    academy = Build.level_of(buildings, "academy")
    for {tech, lv} <- research || %{}, academy > 0, into: %{}, do: {tech, min(lv, academy)}
  end

  @doc "The player's level of tech, 0 when never researched."
  def level_of(research, tech), do: Map.get(research || %{}, tech, 0)

  @doc """
  Whether a city's buildings and the player's research meet a level's needs: "requires" (buildings and levels in
  this city) and "research" (techs and levels). Used for research levels and for buildings that need research
  (Relief Station needs Horseback Riding).
  """
  def met?(buildings, research, needs) do
    Enum.all?(needs["requires"] || %{}, fn {type, lv} -> Build.level_of(buildings, type) >= lv end) and
      Enum.all?(needs["research"] || %{}, fn {tech, lv} -> level_of(research, tech) >= lv end)
  end

  @doc "Construction: each level makes building 10% faster than the level before (time x 0.9^level)."
  def build_seconds(seconds, research) do
    case level_of(research, "construction") do
      0 -> seconds
      lv -> round(seconds * :math.pow(0.9, lv))
    end
  end

  @doc """
  The research bonus to a resource field's production, as a percentage of what the fields make: Agriculture
  for food, Lumbering for lumber, Masonry for stone, Mining for iron, +10% each level.
  """
  def production_bonus(research, "food"), do: 10 * level_of(research, "agriculture")
  def production_bonus(research, "lumber"), do: 10 * level_of(research, "lumbering")
  def production_bonus(research, "stone"), do: 10 * level_of(research, "masonry")
  def production_bonus(research, "iron"), do: 10 * level_of(research, "mining")
  def production_bonus(_research, _resource), do: 0

  @doc "Stockpile: warehouses hold 10% more each level."
  def storage_bonus(research), do: 10 * level_of(research, "stockpile")

  defp has_academy(buildings) do
    if Build.level_of(buildings, "academy") > 0, do: :ok, else: {:error, "no_academy"}
  end

  defp requirements(buildings, research, needs) do
    if met?(buildings, research, needs), do: :ok, else: {:error, "requirement_not_met"}
  end
end
