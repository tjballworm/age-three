defmodule Age3.Lord do
  # The made-up lords' towns on the world map: "city" tiles from Age3.World that no real player holds (Ostden and
  # the like). TJ, 2026-11-04: they get a random garrison and a compact defense (walls full of archer towers), and
  # they can be attacked. They fight and refill like an NPC (Age3.Npc; their state is kept in npc_states too), but:
  #
  #   * The garrison is random for each town and never changes: a mix of warriors, pikemen, swordsmen, archers,
  #     cavalry and (from level 5) cataphracts, 50% to 150% the size of an NPC garrison of the same level.
  #   * The walls are full of archer's towers (3 spaces each, Walls.md) and nothing else, even below wall level 3.
  #   * Research and walls equal the town's level and there is no hero, as for NPCs. They hold an NPC's resources.
  #   * A win plunders them but they can't be captured (nobody owns them) and they drop no medals.
  #
  # Names and lords come from the same hash as generateWorld() in packages/core/src/world/index.ts.
  @moduledoc false

  alias Age3.{Data, Game, World}

  @types ~w(warrior pike sword archer cavalry cataphract)
  # (tunable) cataphracts only from this level up
  @cataphract_level 5
  # fortified-unit spaces of walls Lv 1-10 (Walls.md); an archer's tower takes 3
  @wall_space [1_000, 3_000, 6_000, 10_000, 15_000, 21_000, 28_000, 36_000, 45_000, 55_000]
  @tower_space 3

  @syllables ~w(ar den val mor kel thra is gal wyn dor bel ost rin sar)
  @lords ~w(Aldric Mira Oskar Selene Grimwald Tamsin Corvin Isolde Brannoc Yara)

  @doc ~s[The full town at x, y of this level: %{"troops", "forts", "resources"} like Age3.Npc.full/1, or nil.]
  def full(x, y, level, seed \\ Game.world_seed()) do
    case Data.npc(level) do
      nil ->
        nil

      npc ->
        %{
          "troops" => garrison(x, y, level, seed, npc["troops"]),
          "forts" => %{"tower" => div(Enum.at(@wall_space, level - 1), @tower_space)},
          "resources" => npc["resources"]
        }
    end
  end

  # NPC garrison size x 0.5-1.5, split by a random weight for each troop type
  defp garrison(x, y, level, seed, npc_troops) do
    total = trunc(Enum.sum(Map.values(npc_troops)) * (0.5 + World.hash(x, y, seed, 30)))

    weights =
      for {type, i} <- Enum.with_index(@types),
          type != "cataphract" or level >= @cataphract_level,
          do: {type, World.hash(x, y, seed, 31 + i)}

    sum = weights |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    for {type, w} <- weights, n = trunc(total * w / sum), n > 0, into: %{}, do: {type, n}
  end

  @doc "The town's name, as the map shows it (generateWorld)."
  def name(x, y, seed \\ Game.world_seed()) do
    s = fn n -> pick(@syllables, World.hash(x, y, seed, 10 + n)) end
    name = s.(0) <> s.(1) <> if(World.hash(x, y, seed, 13) < 0.4, do: s.(2), else: "")
    String.capitalize(name)
  end

  @doc "The town's lord, as the map shows it (generateWorld)."
  def owner(x, y, seed \\ Game.world_seed()), do: pick(@lords, World.hash(x, y, seed, 20))

  defp pick(list, r), do: Enum.at(list, floor(r * length(list)))
end
