defmodule Age3.Npc do
  # NPC (barbarian) cities, as pure functions. A full NPC of each level comes from priv/data/npcs.json (the wiki's
  # tables). NPC research and walls equal its level, and it has no hero (TJ, 2026-11-03).
  #
  # After a battle an NPC refills a little every second (TJ, 2026-11-03): each troop type and fortification gets
  # back full / 3600 per second, and each resource full / 28800 per second, never above full. Nothing ticks: the
  # store keeps what was left and when (npc_states), and current/3 works out the rest when it is needed.
  @moduledoc false

  alias Age3.{Combat, Data}

  @doc ~s(A full NPC of this level: %{"troops" => ..., "forts" => ..., "resources" => ...}, or nil.)
  def full(level), do: Data.npc(level)

  @doc """
  The NPC as it stands at now_ms. saved is what was left after its last battle (%{level, troops, forts,
  resources, updated_at_ms}) or nil for one never attacked (full). Whole seconds since then count; amounts are
  whole numbers. Instead of a level it can take the full NPC itself (a lord's town, Age3.Lord.full/3, or a
  historic city, Age3.Historic.full/3). periods is {garrison, resources}: the seconds each takes to refill from
  empty (an NPC's by default).
  """
  def current(saved, level_or_full, now_ms, periods \\ Data.npc_regen_seconds())

  def current(saved, level, now_ms, periods) when is_integer(level),
    do: current(saved, full(level), now_ms, periods)

  def current(nil, full, _now_ms, _periods), do: full

  def current(saved, full, now_ms, {garrison, resources}) do
    secs = div(max(0, now_ms - saved.updated_at_ms), 1000)

    %{
      "troops" => refill(saved.troops, full["troops"], secs, garrison),
      "forts" => refill(saved.forts, full["forts"], secs, garrison),
      "resources" => refill(saved.resources, full["resources"], secs, resources)
    }
  end

  defp refill(left, full, secs, period) do
    Map.new(full, fn {k, max} -> {k, min(max, Map.get(left, k, 0) + div(max * secs, period))} end)
  end

  @doc "The battle engine's defender, fortifications and settings for this NPC as it stands."
  def battle(npc, level) do
    v = level

    defender = %{
      Combat.default_army()
      | troops: npc["troops"],
        tech: %{
          military_tradition: v,
          iron_working: v,
          compass: v,
          horseback_riding: v,
          archery: v,
          medicine: v,
          engineering: v,
          machinery: v
        },
        heal_percent: 0
    }

    {defender, npc["forts"], %{Combat.default_settings() | walls: level, npc: true}}
  end

  @doc "What is left of the NPC after a battle (troops survived, fortifications remaining), less the loot taken."
  def after_battle(npc, result, loot) do
    troops =
      for t <- result.defender.troops,
          Map.has_key?(npc["troops"], t.type),
          into: %{},
          do: {t.type, t.survived}

    forts =
      for f <- result.fortifications, Map.has_key?(npc["forts"], f.type), into: %{}, do: {f.type, f.remaining}

    resources = Map.new(npc["resources"], fn {k, v} -> {k, v - Map.get(loot, k, 0)} end)
    %{"troops" => troops, "forts" => forts, "resources" => resources}
  end
end
