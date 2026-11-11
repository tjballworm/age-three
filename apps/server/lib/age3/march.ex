defmodule Age3.March do
  # Marches, as pure functions (no database), like Age3.Train: whether an attack can leave, how long it takes, the
  # food it takes along, what it can carry back and what it takes from an NPC. Matches packages/core/src/rules/
  # march.ts, which the March window uses to show the numbers first.
  #
  # Playtest 1 has one mission: attacking an NPC city (TJ, 2026-11-03). A march needs a Rally Spot (it sends up to
  # 10,000 troops per level, and one march out at a time per level) and an idle hero in the city. Troops, hero and
  # food leave the city when it sets off; the survivors, the hero and the loot come back when it returns. A camp
  # wave (TJ, 2026-11-09) makes the army wait at the target before it attacks, to time hits.
  @moduledoc false

  alias Age3.{Combat.Units, Data, Research, World}

  # every march is this many times faster than the original game (TJ, 2026-11-03: 5x for the test server)
  @speed 5
  @troops_per_rally_level 10_000
  # the longest camp wave: a march waits at most this many seconds at its target before attacking
  @max_camp 24 * 3600

  def speed, do: @speed

  @doc """
  Can this attack leave? buildings and research are the city's (research capped with Research.in_city), troops
  the city's troops, hero the hero sent (a map with :status, or nil), from the city's {x, y}, to the target
  {x, y}, food the city's settled food, send the troops to send (%{"warrior" => 100}).

  target is what stands at `to` (Age3.Pvp.target/3): {:npc, level}, {:lord, level}, {:historic, level},
  {:city, city} or {:error, code}; left out, only an NPC will do.

  opts: :rally_multiplier, a held historic city's Rally Spot sends more (Age3.Historic.rally_multiplier/1);
  :marches, how many marches the city has out already (one per Rally Spot level at a time); :camp, the camp wave
  in seconds (the army waits that long at the target before it attacks, and eats food meanwhile).

  Returns {:ok, %{troops, seconds, camp, food, level}} (seconds each way, level of the NPC, lord's town or
  historic city attacked, nil for a player city) or {:error, code}.
  """
  def check(buildings, research, troops, hero, from, to, food, send, target \\ nil, opts \\ []) do
    rally = level_of(buildings, "rallyspot")
    send = for {t, n} <- send || %{}, n > 0, into: %{}, do: {t, n}
    camp = Keyword.get(opts, :camp, 0)

    with :ok <- valid_troops(send),
         :ok <- valid_camp(camp),
         :ok <- if(rally > 0, do: :ok, else: {:error, "no_rally_spot"}),
         :ok <-
           if(Keyword.get(opts, :marches, 0) < max_marches(rally),
             do: :ok,
             else: {:error, "too_many_marches"}
           ),
         :ok <-
           if(total(send) <= floor(rally * @troops_per_rally_level * Keyword.get(opts, :rally_multiplier, 1)),
             do: :ok,
             else: {:error, "too_many_troops"}
           ),
         :ok <-
           if(Enum.all?(send, fn {t, n} -> Map.get(troops, t, 0) >= n end),
             do: :ok,
             else: {:error, "not_enough_troops"}
           ),
         :ok <- hero_ready(hero),
         {:ok, level} <- target_level(target, to) do
      seconds = seconds(from, to, send, research)
      cost = food(send, seconds, camp)

      if food >= cost,
        do: {:ok, %{troops: send, seconds: seconds, camp: camp, food: cost, level: level}},
        else: {:error, "not_enough_resources"}
    end
  end

  @doc "How many marches a city can have out at once (going, camping or coming home): one per Rally Spot level."
  def max_marches(rally_level), do: max(0, rally_level)

  defp valid_camp(camp) when is_integer(camp) and camp >= 0 and camp <= @max_camp, do: :ok
  defp valid_camp(_camp), do: {:error, "bad_message"}

  defp valid_troops(send) do
    cond do
      send == %{} -> {:error, "no_troops"}
      Enum.all?(send, fn {t, n} -> Data.troop(t) != nil and is_integer(n) end) -> :ok
      true -> {:error, "bad_message"}
    end
  end

  defp hero_ready(nil), do: {:error, "no_hero"}
  defp hero_ready(%{status: "idle"}), do: :ok
  defp hero_ready(_hero), do: {:error, "hero_busy"}

  defp target_level(nil, to), do: npc_at(to)
  defp target_level({:npc, level}, _to), do: {:ok, level}
  defp target_level({:lord, level}, _to), do: {:ok, level}
  defp target_level({:historic, level}, _to), do: {:ok, level}
  defp target_level({:city, _city}, _to), do: {:ok, nil}
  defp target_level({:error, code}, _to), do: {:error, code}

  defp npc_at({x, y}) do
    case World.tile_at(x, y) do
      %{kind: "npc", level: level} -> {:ok, level}
      _ -> {:error, "bad_target"}
    end
  end

  @doc """
  Tiles per hour for one troop type: the wiki's speed (miles per 1,000 minutes) x 60 / 1000, +10% per Compass
  level for infantry, archers and scouts, +5% per Horseback Riding level for everything else, x @speed.
  """
  def tiles_per_hour(type, research) do
    bonus =
      if Units.compass?(type),
        do: 1 + Research.level_of(research, "compass") * 0.1,
        else: 1 + Research.level_of(research, "horsebackRiding") * 0.05

    Units.stats(type).speed * 60 / 1000 * bonus * @speed
  end

  @doc "Seconds from one tile to another ({x, y}); the slowest troop type sets the pace. At least 1."
  def seconds(from, to, troops, research) do
    slowest = troops |> Map.keys() |> Enum.map(&tiles_per_hour(&1, research)) |> Enum.min()
    max(1, ceil(distance(from, to) / slowest * 3600))
  end

  @doc "Shortest distance between two tiles on the wrapping world. Matches distance() in packages/core."
  def distance({ax, ay}, {bx, by}) do
    size = Age3.Game.world_size()
    dx = abs(ax - bx)
    dy = abs(ay - by)
    :math.sqrt(:math.pow(min(dx, size - dx), 2) + :math.pow(min(dy, size - dy), 2))
  end

  @doc """
  Food the army eats there and back, paid when it leaves: upkeep per hour x (the round trip + the camp wave it
  waits at the target), rounded up.
  """
  def food(troops, seconds, camp \\ 0), do: ceil(Age3.Train.upkeep(troops) * (2 * seconds + camp) / 3600)

  @doc "Resources the army can carry back: each troop's load, +10% per Logistics level, rounded down."
  def load(troops, research) do
    base = Enum.sum(for {t, n} <- troops, do: Data.troop(t)["load"] * n)
    floor(base * (1 + Research.level_of(research, "logistics") * 0.1))
  end

  @doc """
  What the army takes from resources (%{"food" => ...}) with room for `load`: everything if it fits, otherwise
  each resource in proportion, rounded down.
  """
  def loot(resources, load) do
    total = resources |> Map.values() |> Enum.sum()

    cond do
      total <= 0 or load <= 0 -> Map.new(resources, fn {k, _} -> {k, 0} end)
      total <= load -> resources
      true -> Map.new(resources, fn {k, v} -> {k, div(v * load, total)} end)
    end
  end

  @doc "The city's troops less the ones sent."
  def take(troops, send), do: Map.new(troops, fn {t, n} -> {t, n - Map.get(send, t, 0)} end)

  @doc "(tunable) Exp a hero earns from a battle: one per enemy troop killed."
  def hero_exp(result), do: result.defender.total_lost

  defp total(troops), do: troops |> Map.values() |> Enum.sum()

  defp level_of(buildings, type) do
    case Enum.find(buildings, &(&1.type == type)) do
      nil -> 0
      b -> b.level
    end
  end
end
