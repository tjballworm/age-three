defmodule Age3.MissionsTest do
  # Scouting, transports, reinforcements, founding cities and valleys, against Postgres.
  # Run with: mix test --include db
  use ExUnit.Case, async: true

  @moduletag :db

  import Ecto.Query

  alias Age3.{Building, City, Repo, Store.Pg}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
  end

  # A player with a rich city: Town Hall 5, Rally Spot 5, Beacon Tower and Academy at `scouting`, Informatics at
  # `scouting`, lots of troops, a Lv5 hero and instant marches.
  defp lord(name, scouting \\ 5) do
    {:ok, id} = Pg.find_or_create_player(name)
    now = System.system_time(:millisecond)
    {:ok, _, [city], []} = Pg.state(id, now)

    spy =
      if scouting > 0,
        do: [
          %{city_id: city.id, slot: "2", type: "beacontower", level: scouting},
          %{city_id: city.id, slot: "3", type: "academy", level: scouting}
        ],
        else: []

    Repo.insert_all(
      Building,
      [
        %{city_id: city.id, slot: "townhall", type: "townhall", level: 5},
        %{city_id: city.id, slot: "1", type: "rallyspot", level: 5},
        %{city_id: city.id, slot: "4", type: "reliefstation", level: 1},
        %{city_id: city.id, slot: "5", type: "embassy", level: 2}
      ] ++ spy,
      on_conflict: {:replace, [:level, :type]},
      conflict_target: [:city_id, :slot]
    )

    rich = Map.new(city.resources, fn {k, v} -> {k, %{v | "amount" => 1_000_000}} end)

    Repo.query!("UPDATE cities SET resources = $1, synced_at = $2 WHERE id = $3", [
      rich,
      DateTime.from_unix!(now, :millisecond),
      Ecto.UUID.dump!(city.id)
    ])

    {:ok, _} = Pg.cheat(id, {:city, city.id}, "setResearch", %{tech: "informatics", level: scouting}, now)

    {:ok, _} =
      Pg.cheat(
        id,
        {:city, city.id},
        "addTroops",
        %{troops: %{"scout" => 1000, "cavalry" => 20_000, "worker" => 500, "transporter" => 100}},
        now
      )

    {:ok, _} = Pg.cheat(id, {:city, city.id}, "instantMarch", %{on: true}, now)

    hero =
      Repo.insert!(%Age3.Hero{
        city_id: city.id,
        name: "Ivo",
        level: 5,
        politics: 10,
        attack: 40,
        intelligence: 30
      })

    %{id: id, city: Repo.get!(City, city.id), hero: hero.id, now: now}
  end

  defp nearest(city, pred) do
    for(d <- 1..120, dx <- -d..d, dy <- [-d, d], do: {city.x + dx, city.y + dy})
    |> Enum.map(fn {x, y} -> {Integer.mod(x, 800), Integer.mod(y, 800)} end)
    |> Enum.find(fn {x, y} -> pred.(Age3.World.tile_at(x, y)) and Repo.get_by(City, x: x, y: y) == nil end)
  end

  defp march(l, {x, y}, troops, opts, hero \\ nil),
    do: Pg.march(l.id, l.city.id, x, y, hero, troops, l.now, opts)

  defp settle(l, at), do: Pg.state(l.id, at)

  describe "scouting" do
    test "an NPC: enough scouts see the garrison, too few die; no Beacon Tower sees nothing" do
      l = lord("Spymaster")
      npc = nearest(l.city, &(&1 == %{kind: "npc", level: 5}))

      assert {:ok, at} = march(l, npc, %{"scout" => 50}, %{"mission" => "scout"})
      {:ok, _, [city], [back]} = settle(l, at)
      assert city.troops["scout"] == 950
      assert back.march.phase == "back" and back.march.troops == %{"scout" => 50}
      [r] = Pg.reports(l.id)
      assert %{kind: "scout", won: true, scout: %{"detail" => "exact", "troops" => troops, "walls" => 5}} = r
      assert troops == Age3.Npc.full(5)["troops"]
      {:ok, full} = Pg.report(l.id, r.id)
      assert full.result == nil

      # too few: the scouts die, the report says why
      {:ok, _, _, []} = settle(l, back.endsAt)

      assert {:ok, at2} =
               Pg.march(l.id, l.city.id, elem(npc, 0), elem(npc, 1), nil, %{"scout" => 49}, back.endsAt, %{
                 "mission" => "scout"
               })

      {:ok, _, [city], []} = settle(l, at2 + 10_000)
      assert city.troops["scout"] == 951
      assert [%{won: false, scout: %{"failed" => "too_few_scouts"}} | _] = Pg.reports(l.id)
    end

    test "a lower scout level sees rounded or no counts; a scout march needs scouts" do
      l = lord("Peeker", 2)
      npc = nearest(l.city, &(&1 == %{kind: "npc", level: 4}))
      assert {:error, "no_scouts"} = march(l, npc, %{"cavalry" => 10}, %{"mission" => "scout"})
      {:ok, at} = march(l, npc, %{"scout" => 40}, %{"mission" => "scout"})
      settle(l, at)
      assert [%{scout: %{"detail" => "approx", "troops" => troops}}] = Pg.reports(l.id)
      assert Enum.all?(troops, fn {_t, n} -> is_integer(n) end)
    end

    test "a player's city: both get a report; open gate scouts fight back" do
      a = lord("Watcher")
      b = lord("Watched", 0)
      target = {b.city.x, b.city.y}
      {:ok, at} = march(a, target, %{"scout" => 10}, %{"mission" => "scout"})
      settle(a, at)

      assert [%{kind: "scout", won: true, scout: %{"detail" => "exact", "troops" => %{"scout" => 1000}}}] =
               Pg.reports(a.id)

      assert [%{side: "scouted", scout: %{"by" => "Watcher", "failed" => false}}] = Pg.reports(b.id)

      :ok = Pg.set_gate(b.id, b.city.id, true, at)

      {:ok, at2} =
        Pg.march(a.id, a.city.id, b.city.x, b.city.y, nil, %{"scout" => 10}, at + 5000, %{
          "mission" => "scout"
        })

      settle(a, at2)
      assert [%{won: false, scout: %{"failed" => "scouts_beaten"}} | _] = Pg.reports(a.id)
    end
  end

  describe "transport and reinforce" do
    test "a transport delivers its cargo to another city and comes back; relief makes it faster" do
      a = lord("Carter")
      b = lord("Receiver")
      {:ok, _} = Pg.cheat(a.id, {:city, a.city.id}, "instantMarch", %{on: false}, a.now)
      target = {b.city.x, b.city.y}
      cargo = %{"food" => 1000, "gold" => 500}

      assert {:error, "too_much_cargo"} =
               march(a, target, %{"worker" => 1}, %{"mission" => "transport", "cargo" => cargo})

      {:ok, arrives} = march(a, target, %{"transporter" => 10}, %{"mission" => "transport", "cargo" => cargo})
      plain = Age3.March.seconds({a.city.x, a.city.y}, target, %{"transporter" => 10}, %{})
      assert div(arrives - a.now, 1000) == ceil(plain / 2)

      {:ok, _, [before], _} = Pg.state(b.id, a.now)
      {:ok, _, _, _} = settle(a, arrives)
      {:ok, _, [after_], _} = Pg.state(b.id, arrives)
      assert_in_delta after_.resources["gold"]["amount"], before.resources["gold"]["amount"] + 500, 400
      assert [%{kind: "transport", side: "defence", loot: ^cargo}] = Pg.reports(b.id)
    end

    test "reinforcing your own city moves the troops for good" do
      a = lord("Mover")
      {:ok, _} = Pg.cheat(a.id, {:city, a.city.id}, "resetCity", %{}, a.now)

      second =
        Repo.insert!(%City{
          player_id: a.id,
          name: "Second",
          x: a.city.x + 3,
          y: a.city.y,
          resources: Age3.Game.starter_resources(),
          population: Age3.Game.starter_population()
        })

      Repo.insert_all(Building, [%{city_id: second.id, slot: "1", type: "rallyspot", level: 1}])
      {:ok, _} = Pg.cheat(a.id, {:city, second.id}, "addTroops", %{troops: %{"cavalry" => 100}}, a.now)

      {:ok, at} =
        Pg.march(a.id, second.id, a.city.x, a.city.y, nil, %{"cavalry" => 60}, a.now, %{
          "mission" => "reinforce"
        })

      {:ok, _, cities, []} = settle(a, at)
      assert Enum.find(cities, &(&1.id == a.city.id)).troops["cavalry"] == 60
      assert Enum.find(cities, &(&1.id == second.id)).troops["cavalry"] == 40
    end

    test "allies can station troops where the Embassy allows; they defend and come back when recalled" do
      a = lord("Helper")
      b = lord("Helped")
      target = {b.city.x, b.city.y}
      assert {:error, "not_allied"} = march(a, target, %{"cavalry" => 100}, %{"mission" => "reinforce"})

      Repo.update_all(Age3.Player, set: [alliance: "Friends"])
      assert {:error, "not_allied"} = march(a, target, %{"cavalry" => 100}, %{"mission" => "reinforce"})
      Repo.update_all(from(c in City, where: c.id == ^b.city.id), set: [allow_garrison: true])

      {:ok, at} = march(a, target, %{"cavalry" => 100}, %{"mission" => "reinforce"})
      {:ok, _, _, [stationed]} = settle(a, at)
      assert stationed.march.phase == "stationed"
      {:ok, _, [host], _} = Pg.state(b.id, at)
      assert [%{owner: "Helper", troops: %{"cavalry" => 100}}] = host.garrisons

      {:ok, back} = Pg.recall(a.id, a.city.id, stationed.id, at + 1000)
      {:ok, _, [home], []} = settle(a, back)
      assert home.troops["cavalry"] == 20_000
      {:ok, _, [host], _} = Pg.state(b.id, back)
      assert host.garrisons == []
    end
  end

  describe "found city and valleys" do
    test "250 workers and 10,000 of each resource found a city on a flat" do
      a = lord("Settler")
      flat = nearest(a.city, &(&1.kind == "flat"))
      assert {:error, "city_cap"} = march(a, flat, %{"worker" => 250}, %{"mission" => "found"})
      Repo.update_all(Age3.Player, set: [title: "knight"])
      assert {:error, "not_enough_workers"} = march(a, flat, %{"worker" => 249}, %{"mission" => "found"})
      {:ok, at} = march(a, flat, %{"worker" => 250, "cavalry" => 5}, %{"mission" => "found"})
      {:ok, _, cities, [back]} = settle(a, at)
      assert length(cities) == 2
      new = Enum.find(cities, &(&1.id != a.city.id))
      assert {new.x, new.y} == flat
      assert_in_delta new.resources["stone"]["amount"], 10_000, 50
      assert back.march.troops == %{"cavalry" => 5}
    end

    test "a valley is fought for, held for its bonus, and capped by the Town Hall" do
      a = lord("Valley Lord")
      v = nearest(a.city, &(&1 == %{kind: "valley", level: 1}))
      terrain = Age3.World.terrain(elem(v, 0), elem(v, 1))
      {:ok, at} = march(a, v, %{"cavalry" => 5000}, %{"mission" => "attack"}, a.hero)
      {:ok, _, [city], _} = settle(a, at)
      assert [%{level: 1, terrain: ^terrain}] = city.valleys
      [r] = Pg.reports(a.id)
      assert r.won and r.title =~ "Took the Lv1"

      assert {:error, "own_valley"} =
               Pg.march(a.id, a.city.id, elem(v, 0), elem(v, 1), nil, %{"cavalry" => 1}, at + 5000, %{})

      # another lord takes it: it is empty, so a win is certain
      b = lord("Valley Thief")
      {:ok, at2} = march(b, v, %{"cavalry" => 10}, %{}, b.hero)
      {:ok, _, [thief], _} = settle(b, at2)
      assert [%{level: 1}] = thief.valleys
      assert [%{kind: "valley", won: false}] = Enum.filter(Pg.reports(a.id), &(&1.kind == "valley"))
    end
  end

  describe "fortifications" do
    defp walls(l, level) do
      Repo.insert_all(Building, [%{city_id: l.city.id, slot: "walls", type: "walls", level: level}],
        on_conflict: {:replace, [:level]},
        conflict_target: [:city_id, :slot]
      )
    end

    test "built in a queue at the walls, limited by space and research; a cancel refunds" do
      a = lord("Builder")
      walls(a, 1)
      assert {:error, "requirement_not_met"} = Pg.build_forts(a.id, a.city.id, "tower", 1, a.now)
      assert {:error, "no_wall_space"} = Pg.build_forts(a.id, a.city.id, "trap", 1001, a.now)
      {:ok, done} = Pg.build_forts(a.id, a.city.id, "trap", 100, a.now)
      assert {:error, "fort_queue_full"} = Pg.build_forts(a.id, a.city.id, "trap", 1, a.now)

      walls(a, 3)
      {:ok, second} = Pg.build_forts(a.id, a.city.id, "trap", 10, a.now)
      assert second > done
      {:ok, _, _, tasks} = Pg.state(a.id, a.now)
      cancel = Enum.find(tasks, &(&1.kind == "fort" and to_string(&1.endsAt) == to_string(second)))
      assert cancel
      assert :ok = Pg.cancel_forts(a.id, a.city.id, cancel.id, a.now)

      {:ok, _, [city], []} = Pg.state(a.id, done)
      assert city.forts == %{"trap" => 100}
    end

    test "they defend a player city, and allies stationed there fight when the gate is open" do
      a = lord("Raider")
      b = lord("Castle")
      c = lord("Friend")
      walls(b, 3)

      Repo.update_all(from(x in City, where: x.id == ^b.city.id),
        set: [forts: %{"trap" => 1000}, allow_garrison: true]
      )

      Repo.update_all(Age3.Player, set: [alliance: "Pact"])
      Repo.update_all(from(p in Age3.Player, where: p.id == ^a.id), set: [alliance: nil])
      {:ok, at} = march(c, {b.city.x, b.city.y}, %{"cavalry" => 100}, %{"mission" => "reinforce"})
      settle(c, at)
      :ok = Pg.set_gate(b.id, b.city.id, true, at)

      # with instant marches off, the attack is seen coming by the Beacon Tower (Lv5 here)
      Repo.update_all(from(p in Age3.Player, where: p.id == ^a.id), set: [instant_march: false])
      {:ok, _} = Pg.march(a.id, a.city.id, b.city.x, b.city.y, a.hero, %{"cavalry" => 20_000}, at + 1000, %{})
      {:ok, _, [seen], _} = Pg.state(b.id, at + 1000)
      assert [%{mission: "attack", from: "Raider", fromCity: %{name: _}} = warning] = seen.incoming
      refute Map.has_key?(warning, :troops)
      {:ok, _, _, [out]} = Pg.state(a.id, at + 1000)
      hit = out.endsAt

      {:ok, _, [city], _} = Pg.state(b.id, hit)
      assert Map.get(city.forts, "trap", 0) < 1000
      assert city.troops["cavalry"] < 20_000
      assert Enum.all?(city.garrisons, &(&1.troops["cavalry"] < 100))
    end
  end
end
