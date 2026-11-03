defmodule Age3.NpcTest do
  use ExUnit.Case, async: true

  alias Age3.Npc

  test "a full NPC comes from the wiki's tables; one never attacked is full" do
    full = Npc.full(1)
    assert full["troops"] == %{"warrior" => 50, "pike" => 40, "sword" => 35, "archer" => 15, "cavalry" => 8}
    assert full["forts"] == %{"trap" => 1000}
    assert Npc.current(nil, 1, 0) == full
    assert Npc.full(11) == nil
  end

  test "refills every second, full / 3600 for troops and forts and full / 28800 for resources, never above full" do
    full = Npc.full(5)
    empty = %{troops: %{}, forts: %{}, resources: Map.new(full["resources"], fn {k, _} -> {k, 0} end)}
    saved = Map.put(empty, :updated_at_ms, 1_000_000)

    # whole seconds only
    assert Npc.current(saved, 5, 1_000_999)["troops"] == Map.new(full["troops"], fn {k, _} -> {k, 0} end)

    half = Npc.current(saved, 5, 1_000_000 + 1800 * 1000)
    assert half["troops"]["pike"] == div(full["troops"]["pike"], 2)
    assert half["forts"]["trap"] == div(full["forts"]["trap"], 2)
    assert half["resources"]["food"] == div(full["resources"]["food"] * 1800, 28_800)

    one = Npc.current(saved, 5, 1_000_000 + 1000)
    assert one["troops"]["pike"] == div(full["troops"]["pike"], 3600)

    assert Npc.current(saved, 5, 1_000_000 + 3600 * 1000)["troops"] == full["troops"]
    assert Npc.current(saved, 5, 1_000_000 + 99_999 * 1000) == full
  end

  test "an NPC fights with its level as research and walls, no hero and no healing" do
    {defender, forts, settings} = Npc.battle(Npc.full(3), 3)
    assert defender.tech.military_tradition == 3 and defender.tech.machinery == 3
    assert defender.hero.level == 0
    assert defender.heal_percent == 0
    assert forts == %{"trap" => 2000, "abatis" => 1000, "tower" => 650}
    assert settings.walls == 3 and settings.npc
  end

  test "after a battle: survivors, forts left and resources less the loot" do
    npc = Npc.full(1)
    {defender, forts, settings} = Npc.battle(npc, 1)
    army = %{Age3.Combat.default_army() | troops: %{"cavalry" => 5000}}
    r = Age3.Combat.simulate(%{attacker: army, defender: defender, fortifications: forts, settings: settings})
    assert r.winner == :attacker

    left = Npc.after_battle(npc, r, %{"food" => 100})
    assert left["troops"] == Map.new(npc["troops"], fn {k, _} -> {k, 0} end)
    assert left["forts"]["trap"] < 1000
    assert left["resources"]["food"] == npc["resources"]["food"] - 100
  end
end
