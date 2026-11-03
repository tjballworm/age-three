defmodule Age3.WorldTest do
  # Age3.World must place the same tiles as generateWorld() in packages/core (the fixture is that generator's
  # output, made by packages/core/scripts/world-fixtures.ts).
  use ExUnit.Case, async: true

  alias Age3.World

  @path Path.expand("../fixtures/world.json", __DIR__)
  @external_resource @path

  setup_all do
    {:ok, fixture: @path |> File.read!() |> Jason.decode!()}
  end

  test "sample tiles match the TypeScript generator", %{fixture: f} do
    for [x, y, kind, level] <- f["samples"] do
      assert World.tile_at(x, y, f["seed"]) == %{kind: kind, level: level}, "tile #{x},#{y}"
    end
  end

  test "the whole map matches the TypeScript generator", %{fixture: f} do
    size = f["size"]
    kinds = f["kinds"]

    digest =
      for y <- 0..(size - 1), x <- 0..(size - 1), reduce: 0 do
        d ->
          t = World.tile_at(x, y, f["seed"])
          Integer.mod(d * 31 + Enum.find_index(kinds, &(&1 == t.kind)) * 32 + t.level, 4_294_967_296)
      end

    assert digest == f["digest"]
  end

  test "coordinates wrap, and historic cities have their levels" do
    assert World.tile_at(800, -800) == %{kind: "historic", level: 18}
    assert World.tile_at(100, 100) == %{kind: "historic", level: 16}
    assert World.tile_at(33, 33) == %{kind: "historic", level: 14}
    assert World.tile_at(27, 9) == %{kind: "historic", level: 12}
    assert World.tile_at(5, 7) == World.tile_at(805, 1607)
  end
end
