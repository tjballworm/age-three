defmodule Age3.Combat do
  # The battle engine on the server: a line-by-line port of packages/core/src/combat/engine.ts, so the server
  # decides every battle and the client can still preview one (the /calc page, the march window) with the same
  # rules. Rules follow the Age II mechanics guide (DxCalc-calibrated). Deterministic: the same input always
  # gives the same result.
  #
  # The two must stay identical, down to the order of floating-point operations, because a casualty count is
  # floor(...) of a float and the reference results sit right on those boundaries. test/age3/combat_test.exs
  # replays battles the TypeScript engine recorded (test/fixtures/combat.json, made by
  # packages/core/scripts/combat-fixtures.ts) and fails on any difference. Change both engines together and
  # regenerate the fixture.
  #
  # The TypeScript engine mutates its troop blocks in place; here the blocks live in a map inside the battle
  # state (st), keyed {:a, i} for attackers, {:d, i} for defenders and :tower, and every step returns a new st.
  @moduledoc false

  alias Age3.Combat.Units

  # removes floating-point noise before rounding reach upwards (1771.0000000000002 stays 1771)
  @eps 1.0e-6
  # an attack that would kill this many times the target's survivors clears the block and keeps the attack
  @clear_factor 100
  @abatis_kills_per_shot 0.535
  @support ["scout", "transporter"]

  # ---------- inputs ----------

  @doc "No research at all."
  def no_tech do
    %{
      military_tradition: 0,
      iron_working: 0,
      compass: 0,
      horseback_riding: 0,
      archery: 0,
      medicine: 0,
      engineering: 0,
      machinery: 0
    }
  end

  @doc """
  An army with no troops: troops %{"warrior" => 100, ...}, tech (see no_tech/0), hero %{level, attack,
  intelligence, leadership, stars}, war_horn, corselet, and heal_percent (share of lost troops healed, 0-100).
  """
  def default_army do
    %{
      troops: %{},
      tech: no_tech(),
      hero: %{level: 0, attack: 0, intelligence: 0, leadership: 0, stars: 0},
      war_horn: false,
      corselet: false,
      heal_percent: 10
    }
  end

  @doc """
  walls 0-10; closed_gates keeps the garrison out; npc means no defender healing; valley 1-10 (0 for a city)
  replaces the defender's troop research and ignores walls.
  """
  def default_settings do
    %{
      walls: 10,
      closed_gates: false,
      npc: false,
      valley: 0,
      max_rounds: 100,
      trap_rate: 8,
      trap_power: 1,
      log_power: 1,
      trebuchet_power: 1
    }
  end

  # ---------- stats ----------

  @doc "Hero Attack/Intelligence coverage per troop type (0-1), from the initial army."
  def hero_coverage(army) do
    stars = Units.star_multipliers(army.hero.stars)

    capacity =
      max(0, army.hero.level) * (10 * max(0, army.hero.leadership) + 100 * stars.leadership)

    start = Map.new(Units.troops(), &{&1, 0})

    {coverage, _left} =
      Enum.reduce(Units.hero_coverage_order(), {start, capacity}, fn t, {cov, cap} ->
        n = int(army.troops[t])

        cond do
          n == 0 -> {cov, cap}
          n <= cap -> {Map.put(cov, t, 1), cap - n}
          # a partly covered block doesn't use the capacity up: later blocks can still be covered
          true -> {Map.put(cov, t, cap / n), cap}
        end
      end)

    coverage
  end

  # ranged reach after research (and the defender's walls), rounded up
  defp ranged_reach(base, archery, walls),
    do: ceil(base * (1 + archery * 0.05) * (1 + walls * 0.03) - @eps)

  @doc "A troop type's attack, defence, life, speed and range in this army."
  def troop_stats(type, army, coverage, walls) do
    base = Units.stats(type)
    %{tech: tech, hero: hero} = army
    star_life = Units.star_multipliers(hero.stars).life
    horn = if army.war_horn, do: 1.2, else: 1
    corselet = if army.corselet, do: 1.2, else: 1
    # operation order is deliberate: it reproduces the reference results at exact casualty boundaries
    attack = base.attack * ((1 + tech.military_tradition * 0.05 + hero.attack * coverage / 200) * horn)
    defence = clamp(base.defence * (1 + tech.iron_working * 0.05) * corselet, 50, 500)
    life = floor(base.life * star_life * (1 + tech.medicine * 0.05) + hero.intelligence * coverage)

    speed =
      base.speed *
        if(Units.compass?(type), do: 1 + tech.compass * 0.1, else: 1 + tech.horseback_riding * 0.05)

    range = if Units.ranged?(type), do: ranged_reach(base.range, tech.archery, walls), else: base.range

    %{
      type: type,
      attack: attack,
      defence: defence,
      life: life,
      speed: speed,
      range: range,
      coverage: coverage
    }
  end

  @doc "Archer towers' stats for this defender."
  def tower_stats(defender, walls) do
    star_life = Units.star_multipliers(defender.hero.stars).life
    t = Units.tower()

    %{
      type: "tower",
      attack: t.attack,
      defence: t.defence,
      life: floor(t.life * (1 + defender.tech.engineering * 0.1) * star_life),
      speed: 0,
      range: ranged_reach(t.range, defender.tech.archery, walls),
      coverage: 0
    }
  end

  @doc "The wall's health: 100,000 x L(L+1)/2, +10% per Engineering level."
  def wall_life(level, engineering), do: 100_000 * level * (level + 1) / 2 * (1 + engineering * 0.1)

  # valley battles: the valley level replaces the defender's troop research; no walls, no Engineering/Machinery
  defp normalise(%{settings: %{valley: v}} = input) when v > 0 do
    tech = %{
      military_tradition: v,
      iron_working: v,
      compass: v,
      horseback_riding: v,
      archery: v,
      medicine: v,
      engineering: 0,
      machinery: 0
    }

    %{input | defender: %{input.defender | tech: tech}, settings: %{input.settings | walls: 0}}
  end

  defp normalise(input), do: input

  # ---------- the battle ----------

  @doc """
  Fights one battle. input is %{attacker: army, defender: army, fortifications: %{"trap" => n, ...},
  settings: settings} (see default_army/0 and default_settings/0). Returns the winner (:attacker or :defender),
  the rounds fought, both sides' troop outcomes, the fortifications used, the wall, and a log of every round.
  Matches simulate() in packages/core/src/combat/engine.ts.
  """
  def simulate(raw) do
    input = normalise(raw)
    %{attacker: att, defender: dfn, settings: settings} = input
    walls = clamp(int(settings.walls), 0, 10)
    closed = settings.closed_gates
    max_rounds = max(1, if(int(settings.max_rounds) == 0, do: 100, else: int(settings.max_rounds)))

    forts = Map.new(Units.forts(), &{&1, int(input.fortifications[&1])})

    # starting distance: longest base range among everything taking part, plus 200
    longest =
      Enum.reduce(Units.troops(), 0, fn t, acc ->
        r = Units.stats(t).range
        acc = if int(att.troops[t]) > 0, do: max(acc, r), else: acc
        if not closed and int(dfn.troops[t]) > 0, do: max(acc, r), else: acc
      end)

    longest =
      Enum.reduce(Units.forts(), longest, fn f, acc ->
        if forts[f] > 0, do: max(acc, Units.fort_range(f)), else: acc
      end)

    battlefield = longest + 200

    {a_blocks, a_stats} = make_side(:attacker, :a, att, 0, battlefield)
    {d_blocks, d_stats} = make_side(:defender, :d, dfn, walls, battlefield)
    t_stats = tower_stats(dfn, walls)

    tower = %{
      id: :tower,
      side: :defender,
      type: "tower",
      ranged: true,
      initial: forts["tower"],
      count: forts["tower"],
      pending: 0,
      position: battlefield,
      attack: t_stats.attack,
      defence: t_stats.defence,
      life: t_stats.life,
      speed: 0,
      range: t_stats.range,
      coverage: 0,
      order: length(Units.troops())
    }

    att_ids = Enum.map(a_blocks, & &1.id)
    d_ids = Enum.map(d_blocks, & &1.id)
    has_wall = walls > 0
    full_wall = if has_wall, do: wall_life(walls, dfn.tech.engineering), else: 0

    ctx = %{
      battlefield: battlefield,
      att_ids: att_ids,
      gar_ids: if(closed, do: [], else: d_ids),
      d_ids: d_ids,
      has_wall: has_wall,
      settings: settings,
      initial_forts: forts
    }

    st = %{
      blocks: Map.new(a_blocks ++ d_blocks ++ [tower], &{&1.id, &1}),
      forts: forts,
      wall: full_wall,
      wall_targetable: false,
      wall_damage: 0,
      events: []
    }

    winner = finish(st, ctx)
    # with the gates closed (or no garrison) and no towers, the wall is a target from round 1
    st = %{st | wall_targetable: Enum.all?(blocks(st, ctx.gar_ids), &(&1.count == 0)) and tower.count == 0}

    {st, winner, rounds, log} = run_rounds(st, ctx, winner, 0, max_rounds, [])
    winner = winner || :defender

    repair_rate = if settings.npc, do: 0, else: min(0.3, 0.03 * dfn.tech.machinery)

    %{
      winner: winner,
      rounds: rounds,
      battlefield: battlefield,
      attacker: summarise(outcome(att, blocks(st, att_ids), att.heal_percent), a_stats),
      defender:
        summarise(
          outcome(dfn, blocks(st, d_ids), if(settings.npc, do: 0, else: dfn.heal_percent)),
          d_stats ++ [t_stats]
        ),
      fortifications:
        Enum.map(Units.forts(), fn f ->
          remaining = if f == "tower", do: st.blocks[:tower].count, else: st.forts[f]
          used = forts[f] - remaining

          %{type: f, initial: forts[f], remaining: remaining, used: used, repaired: floor(used * repair_rate)}
        end),
      wall: %{level: walls, life: full_wall, remaining: st.wall},
      log: Enum.reverse(log)
    }
  end

  defp make_side(side, prefix, army, range_walls, battlefield) do
    cover = hero_coverage(army)
    stats = Enum.map(Units.troops(), &troop_stats(&1, army, cover[&1], range_walls))

    blocks =
      for {t, i} <- Enum.with_index(Units.troops()), n = int(army.troops[t]), n > 0 do
        s = Enum.at(stats, i)

        %{
          id: {prefix, i},
          side: side,
          type: t,
          ranged: Units.ranged?(t),
          initial: n,
          count: n,
          pending: 0,
          position: if(side == :attacker, do: 0, else: battlefield),
          attack: s.attack,
          defence: s.defence,
          life: s.life,
          speed: s.speed,
          range: s.range,
          coverage: s.coverage,
          order: i
        }
      end

    {blocks, stats}
  end

  defp run_rounds(st, _ctx, winner, round, max_rounds, log) when winner != nil or round >= max_rounds,
    do: {st, winner, round, log}

  defp run_rounds(st, ctx, nil, round, max_rounds, log) do
    round = round + 1
    st = %{st | events: [], wall_damage: 0}
    before = {total(st, ctx.att_ids), total(st, ctx.d_ids) + st.blocks[:tower].count}

    st = st |> move(ctx) |> attack(ctx) |> apply_casualties(ctx)
    {st, wall_broke} = damage_wall(st, ctx)
    skip_volleys = wall_broke and st.forts["log"] == 0
    st = st |> volleys(ctx, skip_volleys) |> towers_fire(ctx) |> trebuchets(ctx, skip_volleys)

    winner = finish(st, ctx)
    # the wall can be attacked from the round after the garrison and towers are gone
    st =
      if total(st, ctx.gar_ids) == 0 and st.blocks[:tower].count == 0,
        do: %{st | wall_targetable: true},
        else: st

    tower = st.blocks[:tower]
    {a_before, d_before} = before
    a_after = total(st, ctx.att_ids)
    d_after = total(st, ctx.d_ids) + tower.count
    shown = blocks(st, ctx.att_ids ++ ctx.gar_ids) ++ if(tower.initial > 0, do: [tower], else: [])

    entry = %{
      round: round,
      attacker_alive: a_after,
      defender_alive: d_after,
      attacker_losses: a_before - a_after,
      defender_losses: d_before - d_after,
      wall_life: st.wall,
      events: Enum.reverse(st.events),
      blocks: Enum.map(shown, &%{side: &1.side, type: &1.type, position: &1.position, count: &1.count})
    }

    run_rounds(st, ctx, winner, round, max_rounds, [entry | log])
  end

  defp finish(st, ctx) do
    attacker_alive = total(st, ctx.att_ids) > 0

    defence_active =
      total(st, ctx.gar_ids) > 0 or st.blocks[:tower].count > 0 or (ctx.has_wall and st.wall > 0)

    cond do
      not attacker_alive -> :defender
      not defence_active -> :attacker
      true -> nil
    end
  end

  # ---------- 1. movement ----------

  defp move(st, ctx) do
    movers = st |> alive(ctx.att_ids ++ ctx.gar_ids) |> Enum.sort(&(move_order(&1, &2) <= 0))
    regulars_left = Enum.any?(alive(st, ctx.att_ids), &(&1.type not in @support))

    Enum.reduce(movers, st, fn %{id: id}, st ->
      b = st.blocks[id]

      cond do
        b.type in @support and b.side == :defender -> st
        b.type in @support and regulars_left -> st
        target_in_reach?(st, ctx, b) -> st
        true -> step(st, ctx, b)
      end
    end)
  end

  defp step(st, ctx, b) do
    dir = if b.side == :attacker, do: 1, else: -1
    tower = st.blocks[:tower]

    blockers =
      alive(st, enemy_ids(ctx, b)) ++ if(b.side == :attacker and tower.count > 0, do: [tower], else: [])

    to =
      Enum.reduce(blockers, b.position + dir * b.speed, fn e, to ->
        cond do
          dir > 0 and e.position >= b.position and e.position < to -> e.position
          dir < 0 and e.position <= b.position and e.position > to -> e.position
          true -> to
        end
      end)

    to = clamp(to, 0, ctx.battlefield)

    if to != b.position do
      st
      |> event("#{side_name(b.side)} #{label(b)} move from #{fmt(b.position)} to #{fmt(to)}.")
      |> put(%{b | position: to})
    else
      st
    end
  end

  defp target_in_reach?(st, ctx, b) do
    tower = st.blocks[:tower]

    Enum.any?(blocks(st, enemy_ids(ctx, b)), &(&1.count > 0 and reaches?(b, dist(b, &1)))) or
      (b.side == :attacker and
         ((tower.count > 0 and reaches?(b, dist(b, tower))) or
            (can_hit_wall?(st, ctx, b) and reaches?(b, ctx.battlefield - b.position))))
  end

  # ---------- 2. ordinary attacks ----------

  # fastest first (defenders first on ties); outgoing damage uses start-of-phase counts
  defp attack(st, ctx) do
    actors = st |> alive(ctx.att_ids ++ ctx.gar_ids) |> Enum.sort(&(attack_order(&1, &2) <= 0))
    Enum.reduce(actors, st, fn a, st -> attack_loop(st, ctx, a, a.count, false, 0) end)
  end

  defp attack_loop(st, _ctx, _a, _outgoing, _reserved, guard) when guard >= 64, do: st

  defp attack_loop(st, ctx, a, outgoing, reserved, guard) do
    reachable = Enum.filter(blocks(st, enemy_ids(ctx, a)), &(live(&1) > 0 and reaches?(a, dist(a, &1))))
    tower = st.blocks[:tower]
    tower_up = a.side == :attacker and live(tower) > 0 and reaches?(a, dist(a, tower))
    again = fn st, reserved -> attack_loop(st, ctx, a, outgoing, reserved, guard + 1) end

    if a.ranged do
      target = if tower_up, do: tower, else: pick_for_shooter(reachable)

      if target do
        d = dist(a, target)
        k = potential_kills(a, outgoing, target, d)

        if k >= @clear_factor * live(target),
          do: st |> hit(a, target, k, d, " (cleared)") |> again.(reserved),
          else: hit(st, a, target, k, d, "")
      else
        attack_wall(st, ctx, a, outgoing, reserved)
      end
    else
      target = reachable |> Enum.sort(&(nearest_pick(a, &1, &2) <= 0)) |> List.first()

      cond do
        target != nil ->
          d = dist(a, target)
          k = potential_kills(a, outgoing, target, d)

          if k > @clear_factor * live(target) do
            # a reachable tower that would have been the better target holds back this block's follow-up on it
            reserved = reserved or (tower_up and nearest_pick(a, tower, target) < 0)
            st |> hit(a, target, k, d, " (cleared)") |> again.(reserved)
          else
            hit(st, a, target, k, d, "")
          end

        tower_up and reserved ->
          st

        tower_up ->
          d = dist(a, tower)
          hit(st, a, tower, potential_kills(a, outgoing, tower, d), d, "")

        true ->
          attack_wall(st, ctx, a, outgoing, reserved)
      end
    end
  end

  defp attack_wall(st, ctx, a, outgoing, reserved) do
    d = ctx.battlefield - a.position

    if can_hit_wall?(st, ctx, a) and not reserved and reaches?(a, d) do
      dmg = outgoing * a.attack * distance_factor(a, nil, d)

      %{st | wall_damage: st.wall_damage + dmg}
      |> event("#{side_name(a.side)} #{label(a)} attack the wall at #{fmt(d)} distance: #{fmt(dmg)} damage.")
    else
      st
    end
  end

  defp hit(st, a, t, kills, d, note) do
    t = st.blocks[t.id]
    k = min(kills, live(t))

    st
    |> put(%{t | pending: t.pending + k})
    |> event(
      "#{side_name(a.side)} #{label(a)} target #{label(t)} at #{fmt(d)} distance: #{k} casualties#{note}."
    )
  end

  defp potential_kills(a, count, t, d) do
    p = a.attack * distance_factor(a, t, d)
    reduced = p - p * t.defence / 1000

    counter =
      cond do
        t.type != "tower" -> Units.counter(a.type, t.type)
        a.ranged -> 1
        true -> 0.3
      end

    floor(count * (reduced * counter) / t.life)
  end

  defp distance_factor(%{ranged: false}, _target, _d), do: 1

  defp distance_factor(a, target, d) do
    melee = target != nil and target.type != "tower" and not target.ranged and d <= target.range + @eps

    cond do
      d <= @eps or melee -> 0.25
      d > a.range / 2 -> 0.5
      true -> 1
    end
  end

  # ---------- 3. casualties and the wall ----------

  defp apply_casualties(st, ctx) do
    Enum.reduce(ctx.att_ids ++ ctx.gar_ids ++ [:tower], st, fn id, st ->
      b = st.blocks[id]
      put(st, %{b | count: b.count - b.pending, pending: 0})
    end)
  end

  defp damage_wall(st, ctx) do
    if ctx.has_wall and st.wall > 0 and st.wall_damage > 0 do
      wall = max(0, st.wall - st.wall_damage)
      st = %{st | wall: wall}
      if wall <= 0, do: {event(st, "The wall is destroyed."), true}, else: {st, false}
    else
      {st, false}
    end
  end

  # ---------- 4. rolling logs, traps, abatis ----------

  defp volleys(st, ctx, skip) do
    s = ctx.settings
    initial = ctx.initial_forts

    st =
      spread(st, ctx, "log", ceil(initial["log"] * 10 / 100), Units.log_targets(), fn b ->
        500 * s.log_power * (1 - b.defence / 1000) / b.life
      end)

    cond do
      skip ->
        st

      true ->
        st =
          if s.trap_rate > 0,
            do:
              spread(st, ctx, "trap", ceil(initial["trap"] * s.trap_rate / 100), Units.trap_targets(), fn _ ->
                0.5 * s.trap_power
              end),
            else: st

        spread(st, ctx, "abatis", ceil(initial["abatis"] * 10 / 100), Units.abatis_targets(), fn _ ->
          @abatis_kills_per_shot
        end)
    end
  end

  defp spread(st, ctx, fort, budget, targets, per_shot) do
    deployed = min(budget, st.forts[fort])
    attackers = blocks(st, ctx.att_ids)

    eligible =
      for t <- targets, b = Enum.find(attackers, &(&1.type == t and &1.count > 0)), b != nil, do: b

    if deployed <= 0 or eligible == [] do
      st
    else
      share = ceil(deployed / length(eligible))

      {st, left} =
        Enum.reduce_while(eligible, {st, deployed}, fn b, {st, left} ->
          shots = min(share, left)

          if shots <= 0 do
            {:halt, {st, left}}
          else
            k = min(b.count, floor(shots * per_shot.(b)))

            st =
              st
              |> put(%{b | count: b.count - k})
              |> event("#{fort_label(fort)} hit #{label(b)} with #{shots}: #{k} casualties.")

            {:cont, {st, left - shots}}
          end
        end)

      %{st | forts: Map.update!(st.forts, fort, &(&1 - (deployed - left)))}
    end
  end

  # ---------- 5. archer towers ----------

  defp towers_fire(st, ctx) do
    tower = st.blocks[:tower]

    target =
      if tower.count > 0,
        do: st |> alive(ctx.att_ids) |> Enum.filter(&reaches?(tower, dist(tower, &1))) |> pick_for_shooter()

    if target do
      d = dist(tower, target)
      factor = if d > tower.range / 2, do: 0.5, else: 1
      tower_power = tower.attack * factor
      total_power = tower.count * tower_power
      k = min(target.count, floor(total_power / (1 - target.defence / 1000) / target.life))

      st
      |> put(%{target | count: target.count - k})
      |> event("Archer towers target #{label(target)} at #{fmt(d)} distance: #{k} casualties.")
    else
      st
    end
  end

  # ---------- 6. defensive trebuchets ----------

  defp trebuchets(st, _ctx, true), do: st

  defp trebuchets(st, ctx, false) do
    deployed = min(ceil(ctx.initial_forts["trebuchet"] * 10 / 100), st.forts["trebuchet"])
    cands = alive(st, ctx.att_ids)

    if deployed > 0 and cands != [] do
      ranged = Enum.filter(cands, & &1.ranged)

      t =
        if ranged != [] do
          ranged
          |> Enum.sort(fn x, y ->
            chain([
              fn -> power(y) - power(x) end,
              fn -> Units.stats(y.type).attack - Units.stats(x.type).attack end,
              fn -> x.order - y.order end
            ]) <= 0
          end)
          |> hd()
        else
          cands |> Enum.sort(&(melee_pick(&1, &2) <= 0)) |> hd()
        end

      per_shot = 800 * ctx.settings.trebuchet_power * (1 - t.defence / 1000) / t.life
      needed = ceil(t.count / per_shot)
      used = min(deployed, needed)
      # enough shots to finish the block kill all of it, even if used * per_shot rounds just below the count
      k = if used >= needed, do: t.count, else: min(t.count, floor(used * per_shot))

      %{st | forts: Map.update!(st.forts, "trebuchet", &(&1 - used))}
      |> put(%{t | count: t.count - k})
      |> event("Defensive trebuchets hit #{label(t)} with #{used}: #{k} casualties.")
    else
      st
    end
  end

  # ---------- targeting ----------

  # Each comparison is negative when x should come before y, like a JavaScript sort comparator.
  defp chain([]), do: 0

  defp chain([f | rest]) do
    v = f.()
    if v != 0, do: v, else: chain(rest)
  end

  defp side_first(x, y) do
    cond do
      x.side == y.side -> 0
      x.side == :defender -> -1
      true -> 1
    end
  end

  defp bool(true), do: 1
  defp bool(false), do: 0

  defp ranged_pick(x, y), do: chain([fn -> power(y) - power(x) end, fn -> x.order - y.order end])

  defp melee_pick(x, y),
    do:
      chain([
        fn -> y.speed - x.speed end,
        fn -> power(y) - power(x) end,
        fn -> y.attack - x.attack end,
        fn -> x.order - y.order end
      ])

  defp nearest_pick(from, x, y),
    do:
      chain([
        fn -> dist(from, x) - dist(from, y) end,
        fn -> power(y) - power(x) end,
        fn -> bool(y.ranged) - bool(x.ranged) end,
        fn -> y.attack - x.attack end,
        fn -> x.order - y.order end
      ])

  defp move_order(x, y),
    do:
      chain([
        fn -> bool(x.ranged) - bool(y.ranged) end,
        fn -> y.speed - x.speed end,
        fn -> side_first(x, y) end,
        fn -> x.order - y.order end
      ])

  defp attack_order(x, y),
    do: chain([fn -> y.speed - x.speed end, fn -> side_first(x, y) end, fn -> x.order - y.order end])

  defp pick_for_shooter(cands) do
    case Enum.filter(cands, & &1.ranged) do
      [] -> cands |> Enum.sort(&(melee_pick(&1, &2) <= 0)) |> List.first()
      ranged -> ranged |> Enum.sort(&(ranged_pick(&1, &2) <= 0)) |> hd()
    end
  end

  defp can_hit_wall?(st, ctx, b),
    do: b.side == :attacker and b.type != "scout" and st.wall_targetable and ctx.has_wall and st.wall > 0

  # ---------- results ----------

  defp outcome(army, blocks, heal_percent) do
    Enum.map(Units.troops(), fn t ->
      initial = int(army.troops[t])

      survived =
        case Enum.find(blocks, &(&1.type == t)),
          do: (
            nil -> initial
            b -> b.count
          )

      lost = initial - survived
      healed = floor(lost * clamp(heal_percent, 0, 100) / 100)

      %{
        type: t,
        initial: initial,
        survived: survived,
        lost: lost,
        healed: healed,
        returned: survived + healed
      }
    end)
  end

  defp summarise(troops, stats) do
    %{
      troops: troops,
      total_initial: Enum.sum(Enum.map(troops, & &1.initial)),
      total_lost: Enum.sum(Enum.map(troops, & &1.lost)),
      total_survived: Enum.sum(Enum.map(troops, & &1.survived)),
      total_healed: Enum.sum(Enum.map(troops, & &1.healed)),
      stats: stats
    }
  end

  # ---------- small helpers ----------

  defp blocks(st, ids), do: Enum.map(ids, &st.blocks[&1])
  defp alive(st, ids), do: st |> blocks(ids) |> Enum.filter(&(&1.count > 0))
  defp total(st, ids), do: st |> blocks(ids) |> Enum.map(& &1.count) |> Enum.sum()
  defp put(st, b), do: %{st | blocks: Map.put(st.blocks, b.id, b)}
  defp event(st, text), do: %{st | events: [text | st.events]}
  defp enemy_ids(ctx, b), do: if(b.side == :attacker, do: ctx.gar_ids, else: ctx.att_ids)

  defp live(b), do: b.count - b.pending
  defp power(b), do: live(b) * b.attack
  defp dist(a, b), do: abs(a.position - b.position)
  defp reaches?(a, d), do: d <= a.range + @eps
  defp clamp(v, lo, hi), do: min(hi, max(lo, v))

  # like the TypeScript int(): whole, never negative, 0 for anything missing
  defp int(v) when is_number(v), do: max(0, floor(v))
  defp int(_v), do: 0

  defp label(%{type: "tower"}), do: "Archer towers"
  defp label(b), do: Units.stats(b.type).name
  defp side_name(:attacker), do: "Attacker"
  defp side_name(:defender), do: "Defender"
  defp fort_label("trebuchet"), do: "Trebuchets"
  defp fort_label(fort), do: Units.fort_name(fort)

  @doc """
  A number as toLocaleString("en-US", {maximumFractionDigits: 2}) writes it: thousands separated by commas, at
  most two decimals (rounded half away from zero on the float's exact value), no trailing zeros.
  """
  def fmt(n) when is_integer(n), do: group(Integer.to_string(n))

  def fmt(n) when is_float(n) and n < 0, do: "-" <> fmt(-n)

  def fmt(n) when is_float(n) do
    # the float's exact value is mantissa x 2^exp; hundredths = mantissa x 2^exp x 100, rounded half up
    {mantissa, exp} = exact(n)

    hundredths =
      if exp >= 0,
        do: mantissa * Integer.pow(2, exp) * 100,
        else: div(2 * mantissa * 100 + Integer.pow(2, -exp), 2 * Integer.pow(2, -exp))

    whole = group(Integer.to_string(div(hundredths, 100)))

    case rem(hundredths, 100) do
      0 -> whole
      c when rem(c, 10) == 0 -> "#{whole}.#{div(c, 10)}"
      c -> whole <> "." <> String.pad_leading(Integer.to_string(c), 2, "0")
    end
  end

  # a positive float as {mantissa, exponent}, exactly
  defp exact(n) do
    <<0::1, e::11, f::52>> = <<n::float>>
    if e == 0, do: {f, -1074}, else: {f + Integer.pow(2, 52), e - 1075}
  end

  defp group("-" <> digits), do: "-" <> group(digits)

  defp group(digits) do
    digits
    |> String.reverse()
    |> String.to_charlist()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end
