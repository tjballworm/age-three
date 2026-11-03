defmodule Age3.World do
  # What stands on each world-map tile, worked out from the map seed like generateWorld() in
  # packages/core/src/world/index.ts, so the server knows where NPC cities, valleys and flats are and what level
  # they are without storing 640,000 tiles. Historic cities sit at fixed spots (Age3.Game.historic_level/2).
  # Player cities are in the database and aren't part of this: the client draws them over the generated map.
  #
  # test/age3/world_test.exs checks this against the TypeScript generator (test/fixtures/world.json, made by
  # packages/core/scripts/world-fixtures.ts). Change both together.
  @moduledoc false

  alias Age3.Game

  # share of the randomly generated tiles for each kind, in order (TILE_MIX); must add up to 1
  @mix [{"valley", 0.7}, {"flat", 0.15}, {"npc", 0.07}, {"city", 0.08}]
  @two32 4_294_967_296

  @doc """
  The tile at (x, y), wrapping around the edges: %{kind, level}. kind is "valley", "flat" (level 0), "npc",
  "city" (a made-up player city the client shows for now; nobody owns it) or "historic" (level 12-18).
  """
  def tile_at(x, y, seed \\ Game.world_seed()) do
    size = Game.world_size()
    x = Integer.mod(x, size)
    y = Integer.mod(y, size)

    case Game.historic_level(x, y) do
      nil ->
        kind = kind_for(hash(x, y, seed, 1))
        level = if kind == "flat", do: 0, else: 1 + floor(hash(x, y, seed, 2) * 10)
        %{kind: kind, level: level}

      level ->
        %{kind: "historic", level: level}
    end
  end

  # the first kind whose running share passes r (the shares are added one by one, as in the TypeScript loop)
  defp kind_for(r) do
    Enum.reduce_while(@mix, 0, fn {kind, share}, acc ->
      acc = acc + share
      if r < acc, do: {:halt, kind}, else: {:cont, acc}
    end)
    |> case do
      kind when is_binary(kind) -> kind
      _ -> "valley"
    end
  end

  @doc """
  The TypeScript hash(): a pseudo-random number in [0, 1) for a tile and a purpose (salt). JavaScript does it with
  32-bit integer maths (Math.imul, ^, >>>); here the same bits come from whole numbers taken mod 2^32.
  """
  def hash(x, y, seed, salt) do
    h = Integer.mod(x * 374_761_393 + y * 668_265_263 + seed * 1_442_695_041 + salt * 2_654_435_761, @two32)
    h = Integer.mod(Bitwise.bxor(h, Bitwise.bsr(h, 13)) * 1_274_126_177, @two32)
    h = Bitwise.bxor(h, Bitwise.bsr(h, 16))
    h / @two32
  end
end
