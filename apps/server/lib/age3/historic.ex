defmodule Age3.Historic do
  # Historic cities (Lv 12, 14, 16 and 18), as pure functions: attacking, capturing and holding them, and their
  # policies. The rules are in design/historic-cities-policies.md (project files) with the defaults TJ was shown
  # on 2026-11-04. The garrisons are in priv/data/historic-cities.json (a copy of
  # packages/core/src/data/historic-cities.json, which explains the sources); the map places them with
  # Age3.Game.historic_level/2.
  #
  # A free historic city (nobody holds it) fights and refills like an NPC (Age3.Npc; its state is kept in
  # npc_states too), but:
  #
  #   * Research 10, walls 10 and the same fortifications and resources at every level.
  #   * A level 100 King or Queen leads the whole garrison (leadership high enough for any of them, as in the
  #     battle calculator) and can't be captured.
  #   * A garrison slot that lists several types (Swordsmen or Pikemen, say) holds one of them, picked again
  #     every day.
  #   * It refills over a day (troops, fortifications and resources; tunable), and at the daily reset (00:00 UTC)
  #     it is full again, loyalty too.
  #   * A battle that kills at least 5% of the full garrison rolls for medals (Justice 40%, Nation 30%,
  #     medals.json), won or lost. A win plunders it.
  #   * Loyalty starts at 100. Each won attack takes 3; it climbs back 1 point every 3 minutes. A win when it is
  #     already 0 captures the city, if the attacker holds fewer than 10 cities (Age3.Pvp.city_cap/0).
  #
  # A captured historic city becomes a player city on its tile (cities.historic_level), keeping its name: Town
  # Hall 10, Walls 10, a Farm, Sawmill, Quarry and Ironmine (Lv 10, the top of our building data), 5,000 of each
  # resource, 50 people and no Rally Spot. From then on it is attacked and captured like any player city. Its
  # Rally Spot sends more troops, and its lord (an Earl or above) can impose policies on other lords' cities in
  # range, a few times a day.
  @moduledoc false

  alias Age3.{Combat, Data, Game, World}

  @day_ms 86_400_000
  # (tunable) seconds to refill the garrison and fortifications, and the resources, from empty
  @regen_seconds {86_400, 86_400}
  # (tunable) share of the full garrison a battle must kill to roll for medals (medals.json: "beat at least 5%")
  @medal_share 0.05
  # a ruler's leadership: enough to lead the biggest garrison (packages/core/src/data/historic.ts)
  @ruler_leadership 99_999
  # (tunable) loyalty a won attack takes, and seconds for it to climb back one point
  @loyalty_per_win 3
  @loyalty_regen_seconds 180
  # a captured historic city's Town Hall, walls and fields, and what it starts with (EvIIEmulator, live capture)
  @captured_buildings [
    {"townhall", "townhall", 10},
    {"walls", "walls", 10},
    {"f0", "farm", 10},
    {"f1", "sawmill", 10},
    {"f2", "quarry", 10},
    {"f3", "ironmine", 10}
  ]
  @captured_resources 5_000
  @captured_people 50
  # how many times the normal troops a held historic city's Rally Spot sends
  @rally_multiplier %{12 => 1.25, 14 => 1.5, 16 => 2.0, 18 => 3.0}
  # policies a day, and the draft area (tiles in any direction; :state for its own state, :map for everywhere)
  @policies_a_day %{12 => 4, 14 => 6, 16 => 8, 18 => 10}
  @draft_area %{12 => 9, 14 => 33, 16 => :state, 18 => :map}
  # the title a lord needs to impose policies
  @policy_title "earl"
  @policies ~w(tax food population draft disarm)

  def regen_seconds, do: @regen_seconds
  def policies, do: @policies
  def policy_title, do: @policy_title

  @doc "Days since the epoch (UTC) at ms: the daily reset is at 00:00 UTC."
  def day(ms), do: div(ms, @day_ms)

  @doc """
  The full historic city at x, y of this level on this day: %{"troops", "forts", "resources"} like
  Age3.Npc.full/1, or nil. Each either/or slot holds one of its types, picked again every day.
  """
  def full(x, y, level, day \\ 0, seed \\ Game.world_seed()) do
    case Data.historic(level) do
      nil ->
        nil

      hc ->
        troops =
          hc["garrison"]
          |> Enum.with_index()
          |> Enum.reduce(%{}, fn {slot, i}, acc ->
            types = slot["types"]
            type = Enum.at(types, floor(World.hash(x, y, seed, 40 + i + 8 * day) * length(types)))
            n = Map.get(slot["counts"] || %{}, type, slot["count"])
            Map.update(acc, type, n, &(&1 + n))
          end)

        %{"troops" => troops, "forts" => hc["forts"], "resources" => hc["resources"]}
    end
  end

  @doc "The battle engine's defender, fortifications and settings for this historic city as it stands."
  def battle(hc, level) do
    spec = Data.historic(level)
    v = spec["research"]
    ruler = spec["ruler"]

    defender = %{
      Combat.default_army()
      | troops: hc["troops"],
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
        hero: %{
          level: ruler["level"],
          attack: ruler["attack"],
          intelligence: ruler["intelligence"],
          leadership: @ruler_leadership,
          stars: 0
        },
        heal_percent: 0
    }

    {defender, hc["forts"], %{Combat.default_settings() | walls: spec["walls"], npc: true}}
  end

  @doc "Whether the battle rolls for medals: it killed at least 5% of the city's full garrison."
  def medals?(full, result) do
    killed = result.defender.troops |> Enum.map(& &1.lost) |> Enum.sum()
    killed >= @medal_share * Enum.sum(Map.values(full["troops"]))
  end

  @doc """
  A free historic city's loyalty at at_ms: what it had at saved_ms plus a point for every 3 minutes since, up to
  100, and 100 again once a daily reset has passed.
  """
  def loyalty(loyalty, saved_ms, at_ms) do
    if day(saved_ms) < day(at_ms),
      do: 100,
      else: min(100, loyalty + div(max(0, at_ms - saved_ms), @loyalty_regen_seconds * 1000))
  end

  @doc """
  After a won attack on a free historic city with this loyalty, by a player holding `cities` cities:
  %{loyalty, captured}. A win at loyalty 0 captures it, if the player has room for another city.
  """
  def after_win(loyalty, cities),
    do: %{
      loyalty: max(0, loyalty - @loyalty_per_win),
      captured: loyalty == 0 and cities < Age3.Pvp.city_cap()
    }

  @doc "A captured historic city's buildings: {slot, type, level}."
  def captured_buildings, do: @captured_buildings

  @doc "What a captured historic city starts with: %{resources (amount of each), people}."
  def captured_stock, do: %{resources: @captured_resources, people: @captured_people}

  @doc "How many times the normal troops a city's Rally Spot sends (historic_level is nil for most cities)."
  def rally_multiplier(historic_level), do: Map.get(@rally_multiplier, historic_level, 1)

  @doc "Policies a historic city of this level can impose a day."
  def policies_a_day(level), do: Map.get(@policies_a_day, level, 0)

  @doc "Policies left today for a held historic city: used counts only on the day it was used."
  def policies_left(level, used, used_day, now_ms),
    do: policies_a_day(level) - if(used_day == day(now_ms), do: used, else: 0)

  @doc """
  Whether a historic city of this level at `from` can impose policies on a city at `to` ({x, y}): within 9 tiles
  (Lv 12) or 33 (Lv 14) in any direction (the map wraps), in its own state (Lv 16), or anywhere (Atlantis).
  """
  def in_range?(level, {fx, fy}, {tx, ty}) do
    case Map.get(@draft_area, level) do
      nil -> false
      :map -> true
      :state -> Game.state_at(fx, fy) == Game.state_at(tx, ty)
      tiles -> wrapped(fx - tx) <= tiles and wrapped(fy - ty) <= tiles
    end
  end

  defp wrapped(d) do
    size = Game.world_size()
    d = Integer.mod(d, size)
    min(d, size - d)
  end

  @doc """
  What a policy takes from the target city. amounts are its resources (%{"gold" => 1234.5, ...}), idle its idle
  people, troops its troops at home. Returns %{"resources", "people", "troops"}: whole numbers, rounded down.

    * tax: 30% of its gold; food: 20% of its food; population: 50% of its idle people. All go to the historic
      city.
    * draft: 5% of its biggest troop type, who join the historic city's army.
    * disarm: 10% of its biggest troop type, disbanded.
  """
  def take("tax", amounts, _idle, _troops), do: taken(%{"gold" => floor(amounts["gold"] * 0.3)}, 0, %{})
  def take("food", amounts, _idle, _troops), do: taken(%{"food" => floor(amounts["food"] * 0.2)}, 0, %{})
  def take("population", _amounts, idle, _troops), do: taken(%{}, floor(idle / 2), %{})
  def take("draft", _amounts, _idle, troops), do: taken(%{}, 0, biggest(troops, 0.05))
  def take("disarm", _amounts, _idle, troops), do: taken(%{}, 0, biggest(troops, 0.1))

  defp taken(resources, people, troops),
    do: %{"resources" => resources, "people" => people, "troops" => troops}

  defp biggest(troops, share) do
    case Enum.max_by(troops, fn {_t, n} -> n end, fn -> nil end) do
      nil -> %{}
      {type, n} -> if floor(n * share) > 0, do: %{type => floor(n * share)}, else: %{}
    end
  end

  @doc "How the reports name a historic city."
  def name(x, y), do: Game.historic_name(x, y)
end
