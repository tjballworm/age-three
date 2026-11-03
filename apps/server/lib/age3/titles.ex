defmodule Age3.Titles do
  # Medals, military ranks and noble titles, as pure functions (no database), like Age3.Build. Matches
  # packages/core/src/data/titles.ts, which the Promotion window uses to show the needs first.
  #
  # Ranks (Civilian, Lieutenant ... General) and titles (Civilian, Knight ... Prinzessin) are two ladders, climbed
  # one step at a time. A rank step needs gold and a Town Hall level in the city that pays, and medals; a title
  # step needs a rank, gold and medals (and prestige, once prestige can be earned). Each title lets a player hold
  # one more city (city_cap/1). Players store rank and title ids ("civilian", "knight").
  #
  # Medals drop from battles (Dominion of Ages' drop table): only a full clear of an NPC that was at full strength
  # drops anything, and each medal of that level is its own roll, so one win can drop several.
  @moduledoc false

  alias Age3.Data

  @doc "The rank or title spec with this id on a ladder (:rank or :title), or nil."
  def spec(ladder, id), do: Enum.find(steps(ladder), &(&1["id"] == id))

  @doc "A rank or title's display name; unknown ids (or nil) count as Civilian."
  def name(ladder, id), do: (spec(ladder, id) || hd(steps(ladder)))["name"]

  @doc "How many cities a title allows: Civilian 1 ... Prinzessin 10."
  def city_cap(title_id), do: (spec(:title, title_id) || hd(steps(:title)))["cities"]

  @doc "The step above id on the ladder, or nil at the top."
  def next(ladder, id) do
    steps = steps(ladder)
    Enum.at(steps, max(0, index(steps, id)) + 1)
  end

  @doc """
  Can the player go one step up the ladder? player is %{military_rank, title, medals, prestige}, gold the paying
  city's settled gold, town_hall its Town Hall level. Returns {:ok, step} (the spec) or {:error, code}.
  """
  def check(ladder, player, gold, town_hall) do
    current = if ladder == :rank, do: player.military_rank, else: player.title
    medals = player.medals || %{}

    case next(ladder, current) do
      nil ->
        {:error, "max_level"}

      step ->
        cond do
          ladder == :rank and town_hall < step["townHall"] ->
            {:error, "requirement_not_met"}

          ladder == :title and rank_below?(player.military_rank, step["rank"]) ->
            {:error, "rank_too_low"}

          ladder == :title and Data.title_checks_prestige?() and player.prestige < step["prestige"] ->
            {:error, "requirement_not_met"}

          Enum.any?(step["medals"], fn {m, n} -> Map.get(medals, m, 0) < n end) ->
            {:error, "not_enough_medals"}

          gold < step["gold"] ->
            {:error, "not_enough_resources"}

          true ->
            {:ok, step}
        end
    end
  end

  @doc "Medals after adding (or with a negative count, taking) some, e.g. add(%{\"cross\" => 2}, %{\"cross\" => -1})."
  def add(medals, more) do
    Enum.reduce(more, medals || %{}, fn {m, n}, acc ->
      case Map.get(acc, m, 0) + n do
        left when left > 0 -> Map.put(acc, m, left)
        _none -> Map.delete(acc, m)
      end
    end)
  end

  @doc "Medals after paying for a step."
  def spend(medals, step), do: add(medals, Map.new(step["medals"], fn {m, n} -> {m, -n} end))

  @doc """
  Whether a battle against an NPC earns medals: the attacker won and wiped out every defending troop, and the
  NPC had its full garrison when the battle started (before is the NPC as it stood, full the full NPC).
  """
  def full_clear?(won, before, full, result) do
    won and before["troops"] == full["troops"] and Enum.all?(result.defender.troops, &(&1.survived == 0))
  end

  @doc """
  The medals one qualifying win against an NPC of this level drops, e.g. %{"rose" => 1}: one roll per medal.
  rand returns a float in [0, 1) (the default is :rand.uniform/0; tests pass their own).
  """
  def roll_npc(level, rand \\ &:rand.uniform/0) do
    for {m, p} <- Data.npc_medal_drops(level), rand.() < p, into: %{}, do: {m, 1}
  end

  defp steps(:rank), do: Data.ranks()
  defp steps(:title), do: Data.titles()

  defp index(steps, id), do: Enum.find_index(steps, &(&1["id"] == id)) || 0

  defp rank_below?(have, need), do: index(Data.ranks(), have) < index(Data.ranks(), need)
end
