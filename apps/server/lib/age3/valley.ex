defmodule Age3.Valley do
  # Valleys, as pure functions (no database). Valleys are the generated world tiles of kind "valley"; each has a
  # level (1-10) and a terrain (Age3.World.terrain/2). A player takes one by attacking it from one of their cities:
  # a free valley is guarded by its own garrison (priv/data/valleys.json: half an NPC of the same level, tunable),
  # which refills over an hour like an NPC's; a valley someone already holds has no garrison, so a win just takes
  # it from them. The winner's city then holds it (the valleys table) and gets its bonus to one resource:
  # Grassland, Swamp and Lake food, Hill iron, Desert stone, Forest lumber (the wiki's table, e.g. Lake Lv10 +35%).
  #
  # A city can hold as many valleys as its Town Hall level (wiki: each Town Hall level allows one more). The bonus
  # is a share of what the city's fields make, like research: Lake Lv10 = +35% of the farms' food.
  @moduledoc false

  alias Age3.{Combat, Data}

  @doc "How many valleys a city can hold: its Town Hall level."
  def cap(town_hall_level), do: max(0, town_hall_level)

  @doc "The resource a terrain helps, e.g. \"food\"."
  def resource(terrain), do: Data.terrain(terrain)["resource"]

  @doc "The bonus (%) a valley of this terrain and level gives to its resource."
  def bonus(terrain, level) when is_integer(level) and level in 1..10,
    do: Enum.at(Data.terrain(terrain)["bonus"], level - 1)

  def bonus(_terrain, _level), do: 0

  @doc """
  The production bonus (%) each resource gets from a city's valleys (a list of %{terrain, level}), e.g.
  %{"food" => 43, "iron" => 5}.
  """
  def bonuses(valleys) do
    Enum.reduce(valleys, %{}, fn v, acc ->
      Map.update(acc, resource(v.terrain), bonus(v.terrain, v.level), &(&1 + bonus(v.terrain, v.level)))
    end)
  end

  @doc ~s(A free valley of this level at full strength, shaped like an NPC: %{"troops", "forts", "resources"}.)
  def full(level), do: %{"troops" => Data.valley_garrison(level), "forts" => %{}, "resources" => %{}}

  @doc """
  The battle engine's defender, fortifications and settings for a valley's garrison: the valley level stands in
  for its research and walls don't count (Age3.Combat handles both through settings.valley).
  """
  def battle(garrison, level) do
    defender = %{Combat.default_army() | troops: garrison, heal_percent: 0}
    {defender, %{}, %{Combat.default_settings() | walls: 0, npc: true, valley: level}}
  end
end
