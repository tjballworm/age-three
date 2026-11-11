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
  @missions ~w(attack scout transport reinforce found)
  @cargo_types ~w(food lumber stone iron gold)
  # (wiki) a new city needs 250 workers and 10,000 of each resource
  @found_workers 250
  @found_resources 10_000

  def speed, do: @speed

  @doc """
  Can this march leave? buildings and research are the city's (research capped with Research.in_city), troops
  the city's troops, hero the hero sent (a map with :status, or nil), from the city's {x, y}, to the target
  {x, y}, food the city's settled food, send the troops to send (%{"warrior" => 100}).

  target is what stands at `to` for this mission (Age3.March.target/4): {:npc, level}, {:lord, level},
  {:historic, level}, {:valley, level}, {:flat, 0}, {:city, city} or {:error, code}; left out, only an NPC will do.

  opts: :mission ("attack" by default, "scout", "transport", "reinforce" or "found"); :rally_multiplier, a held
  historic city's Rally Spot sends more (Age3.Historic.rally_multiplier/1); :marches, how many marches the city
  has out already (one per Rally Spot level at a time); :camp, the camp wave in seconds (attacks only: the army
  waits that long at the target before it attacks, and eats food meanwhile); :cargo, resources a transport
  carries (%{"food" => 100}), and :stock, the city's settled amounts to pay them from; :relief, how many times
  faster a transport or reinforcement goes (the Relief Station, Age3.March.relief/1).

  Returns {:ok, %{troops, seconds, camp, food, level, cargo}} (seconds each way, level of whatever stands there,
  nil for a player city) or {:error, code}.
  """
  def check(buildings, research, troops, hero, from, to, food, send, target \\ nil, opts \\ []) do
    rally = level_of(buildings, "rallyspot")
    send = for {t, n} <- send || %{}, n > 0, into: %{}, do: {t, n}
    camp = Keyword.get(opts, :camp, 0)
    mission = Keyword.get(opts, :mission, "attack")
    cargo = mission_cargo(mission, Keyword.get(opts, :cargo))

    with :ok <- if(mission in @missions, do: :ok, else: {:error, "bad_message"}),
         :ok <- valid_troops(send),
         :ok <- valid_camp(camp),
         :ok <- if(camp == 0 or mission == "attack", do: :ok, else: {:error, "bad_message"}),
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
         :ok <- mission_troops(mission, send),
         :ok <- mission_hero(mission, hero),
         {:ok, cargo} <- valid_cargo(cargo),
         :ok <- if(total(cargo) <= load(send, research), do: :ok, else: {:error, "too_much_cargo"}),
         {:ok, level} <- target_level(target, to) do
      relief = if mission in ["transport", "reinforce"], do: Keyword.get(opts, :relief, 1), else: 1
      seconds = max(1, ceil(seconds(from, to, send, research) / relief))
      cost = food(send, seconds, camp)
      stock = Keyword.get(opts, :stock, %{})
      need = Map.update(cargo, "food", cost, &(&1 + cost))

      cond do
        food < cost ->
          {:error, "not_enough_resources"}

        cargo != %{} and Enum.any?(need, fn {k, v} -> Map.get(stock, k, 0) < v end) ->
          {:error, "not_enough_resources"}

        true ->
          {:ok, %{troops: send, seconds: seconds, camp: camp, food: cost, level: level, cargo: cargo}}
      end
    end
  end

  @doc """
  What a march with this mission can go to. city is the player city standing on the tile (or nil), tile
  World.tile_at's %{kind, level}, player_id the sender. Returns {:city, city} | {:npc, level} | {:lord, level}
  | {:historic, level} | {:valley, level} | {:flat, 0} | {:error, code}.

  Attack: other players' cities, NPCs, lords' towns, historic cities and valleys (a won valley is taken). Scout:
  the same, and flats. Transport and reinforce: any player's city, your own too (an ally's for reinforcing,
  checked by the store). Found: an empty flat.
  """
  def target(mission, city, tile, player_id)

  def target(m, %{player_id: owner}, _tile, player_id) when m in ["attack", "scout"] and owner == player_id,
    do: {:error, "own_city"}

  def target(m, %{} = city, _tile, _player_id) when m in ["attack", "scout", "transport", "reinforce"],
    do: {:city, city}

  def target(m, nil, %{kind: "npc", level: level}, _p) when m in ["attack", "scout"], do: {:npc, level}
  def target(m, nil, %{kind: "city", level: level}, _p) when m in ["attack", "scout"], do: {:lord, level}
  def target(m, nil, %{kind: "historic", level: l}, _p) when m in ["attack", "scout"], do: {:historic, l}
  def target(m, nil, %{kind: "valley", level: level}, _p) when m in ["attack", "scout"], do: {:valley, level}
  def target(m, nil, %{kind: "flat"}, _p) when m in ["scout", "found"], do: {:flat, 0}
  def target(_m, _city, _tile, _player_id), do: {:error, "bad_target"}

  @doc """
  How many times faster transports and reinforcements go with the sending city's Relief Station (wiki: 2x at
  Lv1, 3x at Lv4, 4x at Lv5, 5x at Lv8, 6x at Lv10). 1 without one.
  """
  def relief(level) when level >= 10, do: 6
  def relief(level) when level >= 8, do: 5
  def relief(level) when level >= 5, do: 4
  def relief(level) when level >= 4, do: 3
  def relief(level) when level >= 1, do: 2
  def relief(_level), do: 1

  @doc "Workers a Found City march takes along; they settle the new city (wiki: 250)."
  def found_workers, do: @found_workers

  @doc "Resources a Found City march takes along to build the new city (wiki: 10,000 of each)."
  def found_cargo, do: Map.new(~w(food lumber stone iron), &{&1, @found_resources})

  defp mission_cargo("found", _cargo), do: found_cargo()
  defp mission_cargo("transport", cargo), do: cargo || %{}
  defp mission_cargo(_mission, _cargo), do: %{}

  defp valid_cargo(cargo) when is_map(cargo) do
    if Enum.all?(cargo, fn {k, v} -> k in @cargo_types and is_integer(v) and v >= 0 end),
      do: {:ok, for({k, v} <- cargo, v > 0, into: %{}, do: {k, v})},
      else: {:error, "bad_message"}
  end

  defp valid_cargo(_cargo), do: {:error, "bad_message"}

  defp mission_troops("scout", send),
    do: if(Map.get(send, "scout", 0) > 0, do: :ok, else: {:error, "no_scouts"})

  defp mission_troops("found", send),
    do: if(Map.get(send, "worker", 0) >= @found_workers, do: :ok, else: {:error, "not_enough_workers"})

  defp mission_troops(_mission, _send), do: :ok

  defp mission_hero("attack", hero), do: hero_ready(hero)
  defp mission_hero("scout", nil), do: :ok
  defp mission_hero("scout", hero), do: hero_ready(hero)
  defp mission_hero(_mission, nil), do: :ok
  defp mission_hero(_mission, _hero), do: {:error, "bad_message"}

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
  defp target_level({:valley, level}, _to), do: {:ok, level}
  defp target_level({:flat, _level}, _to), do: {:ok, 0}
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
