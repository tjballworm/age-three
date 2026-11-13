defmodule Age3.Scout do
  # Scouting, as pure functions (no database). The rules are plans/scouting-plan.md (project files), which TJ
  # approved on 2026-11-03, widened to every target now that valleys and players' cities can be scouted:
  #
  #   * A scout mission needs at least one scout. Other troops may go along; a hero is optional.
  #   * The scout level S = the sending city's Informatics, plus 1 for every 25 points of the hero's Intelligence
  #     (at most +2). No Beacon Tower is needed (TJ, 2026-11-13). Without Informatics S = 0, which always fails.
  #   * Against an NPC city, a lord's town, a historic city or a valley of level L, it needs 10 scouts per level
  #     (wiki); fewer and it fails. Flats have nothing to see and always succeed.
  #   * Against a player's city, its level L is the owner's Informatics there plus 1 for every 25 points of its
  #     defending hero's Intelligence (at most +2), so a well-researched city is harder to read. If its gate is
  #     open, its scouts at home fight yours: you need more scouts than it has (tunable).
  #   * A failure kills every scout sent; other troops come home. A success kills nobody.
  #   * What a success shows rises with S against L: always the resources, walls, and which troop and
  #     fortification types are there; at S >= ceil(L / 2) the counts rounded to two figures, the buildings and
  #     whether the gate is open; at S >= L the exact counts, the research and the heroes.
  @moduledoc false

  alias Age3.Research

  @scouts_per_level 10
  @int_per_level 25
  @max_hero_bonus 2

  @doc "Bonus levels from a hero's Intelligence: +1 per 25, at most +2. nil (no hero) gives 0."
  def hero_bonus(nil), do: 0
  def hero_bonus(intelligence), do: min(@max_hero_bonus, div(max(0, intelligence), @int_per_level))

  @doc "The scout level of a march: Informatics + the hero's bonus; 0 without Informatics."
  def level(0, _intelligence), do: 0
  def level(informatics, intelligence), do: informatics + hero_bonus(intelligence)

  @doc "A player city's scouting level: the owner's Informatics there plus its defending hero's bonus."
  def city_level(research, guard_intelligence),
    do: Research.level_of(research, "informatics") + hero_bonus(guard_intelligence)

  @doc "Scouts needed against a target of this level (NPC, lord's town, historic city or valley)."
  def needed(level), do: @scouts_per_level * level

  @doc """
  Does a scout mission get through? s is the scout level, scouts how many scouts were sent; target is
  {:level, l} for NPCs, lords' towns, historic cities and valleys, {:city, defending_scouts_or_nil} for a
  player's city (nil when its gate is closed), or :flat. Returns :ok or {:error, reason}.
  """
  def outcome(0, _scouts, _target), do: {:error, "no_informatics"}
  def outcome(_s, scouts, _target) when scouts < 1, do: {:error, "no_scouts"}
  def outcome(_s, _scouts, :flat), do: :ok

  def outcome(_s, scouts, {:level, l}),
    do: if(scouts >= needed(l), do: :ok, else: {:error, "too_few_scouts"})

  def outcome(_s, _scouts, {:city, nil}), do: :ok

  def outcome(_s, scouts, {:city, defenders}),
    do: if(scouts > defenders, do: :ok, else: {:error, "scouts_beaten"})

  @doc "How much a successful scout sees: :basic, :approx or :exact, from the scout level s and target level l."
  def detail(s, l) do
    cond do
      s >= l -> :exact
      s >= div(l + 1, 2) -> :approx
      true -> :basic
    end
  end

  @doc "A count as the report shows it: exact, about (two significant figures) or nil (hidden)."
  def shown(_n, :basic), do: nil
  def shown(n, :exact), do: n
  def shown(n, :approx) when n < 100, do: n

  def shown(n, :approx) do
    digits = n |> Integer.to_string() |> String.length()
    unit = Integer.pow(10, digits - 2)
    round(n / unit) * unit
  end

  @doc """
  The report of a successful scout. what is a map of what stands there: "resources" (%{"food" => n}), "walls",
  "troops" and "forts" (%{type => n}), and optionally "research", "buildings", "heroes" and "gateOpen". Returns
  the same keys, cut down to what this detail may see, plus "detail".
  """
  def report(what, detail) do
    counts = fn m -> for {k, n} <- m || %{}, n > 0, into: %{}, do: {k, shown(n, detail)} end

    base = %{
      "detail" => Atom.to_string(detail),
      "resources" => Map.new(what["resources"] || %{}, fn {k, v} -> {k, trunc(v)} end),
      "walls" => what["walls"] || 0,
      "troops" => counts.(what["troops"]),
      "forts" => counts.(what["forts"])
    }

    base
    |> put_if(detail in [:approx, :exact], "buildings", what["buildings"])
    |> put_if(detail in [:approx, :exact], "gateOpen", what["gateOpen"])
    |> put_if(detail == :exact, "research", what["research"])
    |> put_if(detail == :exact, "heroes", what["heroes"])
  end

  defp put_if(map, true, key, value) when value != nil, do: Map.put(map, key, value)
  defp put_if(map, _show, _key, _value), do: map
end
