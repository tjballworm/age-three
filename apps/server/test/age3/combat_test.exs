defmodule Age3.CombatTest do
  # Age3.Combat must give exactly what the TypeScript engine (packages/core/src/combat/engine.ts) gives. The
  # fixture is battles that engine recorded (packages/core/scripts/combat-fixtures.ts); each one is replayed here
  # and compared field by field. A failure prints the first battle that differs.
  use ExUnit.Case, async: true

  alias Age3.Combat

  @path Path.expand("../fixtures/combat.json", __DIR__)
  @external_resource @path

  setup_all do
    %{"cases" => cases} = @path |> File.read!() |> Jason.decode!()
    %{cases: cases}
  end

  test "every recorded battle comes out exactly as in the TypeScript engine", %{cases: cases} do
    assert length(cases) >= 500

    for {%{"input" => input, "result" => want}, i} <- Enum.with_index(cases) do
      got = input |> to_input() |> Combat.simulate() |> to_fixture(Map.has_key?(want, "log"))

      if got != want,
        do: flunk("battle #{i} differs:\n" <> diff(want, got) <> "\ninput: #{Jason.encode!(input)}")
    end
  end

  test "a few worked examples from the mechanics guide" do
    army = fn troops, tech ->
      %{Combat.default_army() | troops: troops, tech: Map.merge(Combat.no_tech(), tech), heal_percent: 0}
    end

    battle = fn a, d, settings ->
      %{
        attacker: a,
        defender: d,
        fortifications: %{},
        settings: Map.merge(Combat.default_settings(), settings)
      }
    end

    # 10,000 scouts against 1,000,000 cataphracts: floor(10000 * 20 * (1 - 350/1000) / 1000) = 130, at any wall
    for walls <- [0, 10] do
      r =
        Combat.simulate(
          battle.(army.(%{"scout" => 10_000}, %{}), army.(%{"cataphract" => 1_000_000}, %{}), %{walls: walls})
        )

      assert Enum.find(r.defender.troops, &(&1.type == "cataphract")).lost == 130
    end

    assert Combat.wall_life(10, 10) == 11_000_000.0
    assert Combat.fmt(1771.0) == "1,771"
    assert Combat.fmt(1234.567) == "1,234.57"
    assert Combat.fmt(5200) == "5,200"
    assert Combat.fmt(0.125) == "0.13"
  end

  # The fixture's camelCase JSON as Age3.Combat's input.
  defp to_input(i) do
    %{
      attacker: army(i["attacker"]),
      defender: army(i["defender"]),
      fortifications: i["fortifications"],
      settings: %{
        walls: i["settings"]["walls"],
        closed_gates: i["settings"]["closedGates"],
        npc: i["settings"]["npc"],
        valley: i["settings"]["valley"],
        max_rounds: i["settings"]["maxRounds"],
        trap_rate: i["settings"]["trapRate"],
        trap_power: i["settings"]["trapPower"],
        log_power: i["settings"]["logPower"],
        trebuchet_power: i["settings"]["trebuchetPower"]
      }
    }
  end

  defp army(a) do
    t = a["tech"]
    h = a["hero"]

    %{
      troops: a["troops"],
      tech: %{
        military_tradition: t["militaryTradition"],
        iron_working: t["ironWorking"],
        compass: t["compass"],
        horseback_riding: t["horsebackRiding"],
        archery: t["archery"],
        medicine: t["medicine"],
        engineering: t["engineering"],
        machinery: t["machinery"]
      },
      hero: %{
        level: h["level"],
        attack: h["attack"],
        intelligence: h["intelligence"],
        leadership: h["leadership"],
        stars: h["stars"]
      },
      war_horn: a["warHorn"],
      corselet: a["corselet"],
      heal_percent: a["healPercent"]
    }
  end

  # Age3.Combat's result in the fixture's shape (see combat-fixtures.ts): camelCase, troop types with no troops
  # left out, stats and the round log only for the battles that keep them. Round-tripped through JSON so numbers
  # compare the way they were recorded.
  defp to_fixture(r, full) do
    side = fn s ->
      base = %{
        "troops" => for(t <- s.troops, t.initial > 0, do: Map.new(t, fn {k, v} -> {to_string(k), v} end)),
        "totalInitial" => s.total_initial,
        "totalLost" => s.total_lost,
        "totalSurvived" => s.total_survived,
        "totalHealed" => s.total_healed
      }

      if full, do: Map.put(base, "stats", s.stats), else: base
    end

    log =
      Enum.map(r.log, fn l ->
        %{
          "round" => l.round,
          "attackerAlive" => l.attacker_alive,
          "defenderAlive" => l.defender_alive,
          "attackerLosses" => l.attacker_losses,
          "defenderLosses" => l.defender_losses,
          "wallLife" => l.wall_life,
          "events" => l.events,
          "blocks" => l.blocks
        }
      end)

    %{
      "winner" => r.winner,
      "rounds" => r.rounds,
      "battlefield" => r.battlefield,
      "attacker" => side.(r.attacker),
      "defender" => side.(r.defender),
      "fortifications" => r.fortifications,
      "wall" => r.wall
    }
    |> then(&if(full, do: Map.put(&1, "log", log), else: &1))
    |> Jason.encode!()
    |> Jason.decode!()
    |> normalise()
  end

  # JSON from JavaScript writes 5200.0 as 5200; make Elixir's floats with no fraction match.
  defp normalise(v) when is_float(v) and v == trunc(v) and abs(v) < 1.0e15, do: trunc(v)
  defp normalise(v) when is_map(v), do: Map.new(v, fn {k, x} -> {k, normalise(x)} end)
  defp normalise(v) when is_list(v), do: Enum.map(v, &normalise/1)
  defp normalise(v), do: v

  # The first few paths where want and got differ.
  defp diff(want, got, path \\ "") do
    cond do
      is_map(want) and is_map(got) ->
        (Map.keys(want) ++ Map.keys(got))
        |> Enum.uniq()
        |> Enum.map(&diff(want[&1], got[&1], "#{path}.#{&1}"))
        |> Enum.reject(&(&1 == ""))
        |> Enum.take(5)
        |> Enum.join("\n")

      is_list(want) and is_list(got) and length(want) == length(got) ->
        Enum.zip(want, got)
        |> Enum.with_index()
        |> Enum.map(fn {{w, g}, i} -> diff(w, g, "#{path}[#{i}]") end)
        |> Enum.reject(&(&1 == ""))
        |> Enum.take(5)
        |> Enum.join("\n")

      want == got ->
        ""

      true ->
        "#{path}: want #{inspect(want, limit: 20)}, got #{inspect(got, limit: 20)}"
    end
  end
end
