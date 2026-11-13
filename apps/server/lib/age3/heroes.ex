defmodule Age3.Heroes do
  # Heroes' rules, as pure functions (no database), like Age3.Train. A hero belongs to a city and lives in its
  # Feasting Hall, which holds as many heroes as its level. The Inn shows as many heroes for hire as its level;
  # the offers change for free every @refresh_ms, and the player can also swap them for new ones by hand, for free,
  # as often as they like (reroll). Hiring costs level x 1,000 gold, and a hero's salary is
  # level x 20 gold an hour, taken off the city's gold rate (Economy.rates).
  #
  # Leadership is the hero's level (TJ, 2026-11-03): +1 per level, heroes stop at level 100. In battle it decides
  # how many troops get the hero's Attack and Intelligence bonus (about 100k at Leadership 100), see heroCoverage
  # in packages/core/src/combat/engine.ts. It isn't stored.
  @moduledoc false

  # (tunable) how often the Inn's offers change
  @refresh_ms 30 * 60_000
  @max_level 100

  @names ~w(Rodney Linda Aldric Beatrix Cedric Daria Edmund Freya Gareth Helena Ivo Johanna Konrad Livia
            Magnus Nadia Osric Petra Quentin Rosalind Sigurd Talia Ulric Vera Wulfric Ysolde Anselm Brunhild
            Casimir Dagny Emeric Fiora Gunther Hilde Isolde Jasper Leopold Matilda Roland Sabine)

  @stats ~w(politics attack intelligence)

  def refresh_ms, do: @refresh_ms
  def max_level, do: @max_level

  @doc "How many heroes the city's Feasting Hall holds: its level, 0 without one."
  def capacity(buildings), do: level_of(buildings, "feastinghall")

  @doc "How many heroes the city's Inn offers: its level, 0 without one."
  def offer_count(buildings), do: level_of(buildings, "inn")

  @doc "Gold paid once to hire a hero."
  def fee(level), do: level * 1_000

  @doc "Gold a hero costs each hour."
  def salary(level), do: level * 20

  @doc "Gold all these heroes cost each hour. heroes are anything with a :level."
  def salaries(heroes), do: Enum.sum(for h <- heroes, do: salary(h.level))

  @doc """
  inn_level new heroes for hire, as JSON-ready maps with string keys. The same seed always gives the same
  heroes, so tests can check them. Each offer gets an id (seed-index), which hire uses to make sure the hero
  being hired is the one the player saw.

  (tunable) A hero's level is 1 to 5 x Inn level. One stat is its strong one, with a base of 45-80 (the wiki: 65+
  makes a good hero); the other two have bases of 15-50. Then each level adds one point to a random stat.
  """
  def roll_offers(inn_level, seed) do
    rand = :rand.seed_s(:exsss, seed)

    {offers, _rand} =
      Enum.map_reduce(0..(inn_level - 1)//1, rand, fn i, rand ->
        {offer, rand} = roll_one(inn_level, rand)
        {Map.put(offer, "id", "#{seed}-#{i}"), rand}
      end)

    offers
  end

  defp roll_one(inn_level, rand) do
    {level, rand} = :rand.uniform_s(inn_level * 5, rand)
    {name_i, rand} = :rand.uniform_s(length(@names), rand)
    {main_i, rand} = :rand.uniform_s(3, rand)
    main = Enum.at(@stats, main_i - 1)

    {base, rand} =
      Enum.reduce(@stats, {%{}, rand}, fn stat, {acc, rand} ->
        {n, rand} = if stat == main, do: between(45, 80, rand), else: between(15, 50, rand)
        {Map.put(acc, stat, n), rand}
      end)

    {stats, rand} =
      Enum.reduce(1..level//1, {base, rand}, fn _, {acc, rand} ->
        {i, rand} = :rand.uniform_s(3, rand)
        {Map.update!(acc, Enum.at(@stats, i - 1), &(&1 + 1)), rand}
      end)

    {Map.merge(stats, %{"name" => Enum.at(@names, name_i - 1), "level" => level}), rand}
  end

  defp between(lo, hi, rand) do
    {n, rand} = :rand.uniform_s(hi - lo + 1, rand)
    {lo + n - 1, rand}
  end

  @doc """
  The Inn as it should be at now_ms. inn is the city's saved %{"refreshAt", "level", "offers"} (or %{}). The
  offers stay until refreshAt, unless the Inn's level changed since they were rolled; then a new set is rolled.
  Returns {inn, changed?}, so the store only saves when something changed. A city without an Inn has no offers.
  """
  def current_inn(inn, inn_level, now_ms, seed \\ nil) do
    cond do
      inn_level == 0 ->
        empty = %{}
        {empty, inn != empty}

      inn["level"] == inn_level and is_integer(inn["refreshAt"]) and now_ms < inn["refreshAt"] ->
        {inn, false}

      true ->
        seed = seed || :erlang.unique_integer([:positive])
        # the next refresh lands on a whole @refresh_ms step, so it doesn't drift with each read
        refresh_at = (div(now_ms, @refresh_ms) + 1) * @refresh_ms
        {%{"refreshAt" => refresh_at, "level" => inn_level, "offers" => roll_offers(inn_level, seed)}, true}
    end
  end

  @doc """
  The player's free refresh: a new set of offers now, from the current Inn (current_inn). The timer isn't touched,
  so the next timed refresh still comes at the same refreshAt. (tunable) No limit and no cost for now.
  """
  def reroll(inn, inn_level, seed \\ nil) do
    seed = seed || :erlang.unique_integer([:positive])
    Map.put(inn, "offers", roll_offers(inn_level, seed))
  end

  @doc """
  Can this city hire the offer with this id? buildings are the city's buildings, heroes its heroes, inn its
  current Inn (current_inn), gold its settled gold. Returns {:ok, offer} or {:error, code}.
  """
  def check_hire(buildings, heroes, inn, offer_id, gold) do
    cond do
      offer_count(buildings) == 0 -> {:error, "no_inn"}
      capacity(buildings) == 0 -> {:error, "no_hall"}
      length(heroes) >= capacity(buildings) -> {:error, "hall_full"}
      true -> hire_offer(inn, offer_id, gold)
    end
  end

  defp hire_offer(inn, offer_id, gold) do
    case Enum.find(inn["offers"] || [], &(&1["id"] == offer_id)) do
      nil -> {:error, "offer_gone"}
      offer -> if gold >= fee(offer["level"]), do: {:ok, offer}, else: {:error, "not_enough_resources"}
    end
  end

  @doc "The Inn without the offer just hired."
  def remove_offer(inn, offer_id),
    do: Map.update!(inn, "offers", &Enum.reject(&1, fn o -> o["id"] == offer_id end))

  @doc "(tunable) Exp a hero needs to go from level to level + 1."
  def exp_to_next(level), do: 100 * level * level

  @doc """
  Adds exp to a hero (anything with :level, :exp and :points). It levels up as many times as the exp covers,
  each level giving +1 level (so +1 Leadership) and +1 unspent stat point, and stops at level 100, where exp no
  longer builds up. Returns the hero with the new level, exp and points.
  """
  def gain_exp(%{level: @max_level} = hero, _exp), do: %{hero | exp: 0}

  def gain_exp(hero, exp) do
    total = hero.exp + exp
    need = exp_to_next(hero.level)

    if total >= need,
      do: gain_exp(%{hero | level: hero.level + 1, exp: 0, points: hero.points + 1}, total - need),
      else: %{hero | exp: total}
  end

  defp level_of(buildings, type) do
    case Enum.find(buildings, &(&1.type == type)) do
      nil -> 0
      b -> b.level
    end
  end

  @doc """
  A mayor's Politics as more production (%) for each field resource (wiki, Stats: +1% per point); nil (no mayor)
  gives none.
  """
  def politics_bonus(nil), do: %{}
  def politics_bonus(politics), do: Map.new(~w(food lumber stone iron), &{&1, max(0, politics)})

  @doc """
  A mayor's stat applied to a task's time (wiki, Stats): construction and fortifications x0.995 per Politics
  point, research x0.995 per Intelligence point, training x0.9986 per Attack point (the Age II rate). mayor is
  the city's mayor or nil. At least 1 second.
  """
  def mayor_seconds(seconds, nil, _kind), do: seconds
  def mayor_seconds(seconds, mayor, :build), do: speed(seconds, 0.995, mayor.politics)
  def mayor_seconds(seconds, mayor, :research), do: speed(seconds, 0.995, mayor.intelligence)
  def mayor_seconds(seconds, mayor, :train), do: speed(seconds, 0.9986, mayor.attack)

  defp speed(seconds, rate, stat), do: max(1, round(seconds * :math.pow(rate, max(0, stat || 0))))

  @doc """
  Spends a hero's unspent points: add is %{"politics" => n, "attack" => n, "intelligence" => n} (any left out
  are 0), each a whole number 0 or more, at most points in all. Returns {:ok, changes} for the hero's row, or
  {:error, "bad_message"} / {:error, "not_enough_points"}. The points are also kept in added, so reset_points can
  give them back.
  """
  def assign(hero, add) do
    stats = ~w(politics attack intelligence)
    adds = for s <- stats, do: Map.get(add, s, 0)

    cond do
      Enum.any?(Map.keys(add), &(&1 not in stats)) ->
        {:error, "bad_message"}

      not Enum.all?(adds, &(is_integer(&1) and &1 >= 0)) ->
        {:error, "bad_message"}

      Enum.sum(adds) == 0 ->
        {:error, "bad_message"}

      Enum.sum(adds) > hero.points ->
        {:error, "not_enough_points"}

      true ->
        [p, a, i] = adds
        added = Map.get(hero, :added) || %{}

        {:ok,
         [
           points: hero.points - p - a - i,
           politics: hero.politics + p,
           attack: hero.attack + a,
           intelligence: hero.intelligence + i,
           added: Map.new(Enum.zip(stats, adds), fn {s, n} -> {s, Map.get(added, s, 0) + n} end)
         ]}
    end
  end

  # (tunable) Bundle 2 and 3 of plans/age2-features-plan.md
  @hired_loyalty 70
  @max_loyalty 100
  @reward_cooldown_ms 15 * 60_000
  @reset_cooldown_ms 24 * 3_600_000
  @lost_attack_loyalty 5
  @capture_below 20

  def hired_loyalty, do: @hired_loyalty
  def reward_cooldown_ms, do: @reward_cooldown_ms
  def reset_cooldown_ms, do: @reset_cooldown_ms

  @doc """
  Raw cost of something paid for (wiki, Experience): food + lumber + 2 x stone + 2.5 x iron + 10 x gold. cost is a
  map of resource => amount (missing ones are 0). Rounded down.
  """
  def raw_cost(cost) do
    cost = cost || %{}
    n = fn k -> Map.get(cost, k, 0) || 0 end
    trunc(n.("food") + n.("lumber") + 2 * n.("stone") + 2.5 * n.("iron") + 10 * n.("gold"))
  end

  @doc "Exp the city's mayor gets when a build, research, fortification or training task it paid for finishes."
  def city_work_exp(cost), do: div(raw_cost(cost), 200)

  @doc """
  Can the player reward this hero (Feasting Hall, wiki)? kind "gold" pays 100 x level gold for 5 loyalty; kind
  "medal" spends one medal for its loyalty (medals.json). One reward per hero per 15 minutes, and not above 100.
  hero has :level, :loyalty, :reward_at (epoch ms or nil). Returns {:ok, %{gold, medal, loyalty}} with what to
  pay and the new loyalty, or {:error, code}.
  """
  def check_reward(hero, kind, medal_id, now_ms, gold, medals) do
    cond do
      hero.status == "captive" ->
        {:error, "hero_busy"}

      hero.reward_at && now_ms < hero.reward_at + @reward_cooldown_ms ->
        {:error, "reward_cooldown"}

      hero.loyalty >= @max_loyalty ->
        {:error, "loyalty_full"}

      kind == "gold" ->
        cost = 100 * hero.level

        if gold >= cost,
          do: {:ok, %{gold: cost, medal: nil, loyalty: min(@max_loyalty, hero.loyalty + 5)}},
          else: {:error, "not_enough_resources"}

      kind == "medal" ->
        case Age3.Data.medal_loyalty(medal_id) do
          nil ->
            {:error, "bad_message"}

          gain ->
            if Map.get(medals || %{}, medal_id, 0) >= 1,
              do: {:ok, %{gold: 0, medal: medal_id, loyalty: min(@max_loyalty, hero.loyalty + gain)}},
              else: {:error, "not_enough_medals"}
        end

      true ->
        {:error, "bad_message"}
    end
  end

  @doc """
  What a lost attack on a player's city does to the hero who led it: -5 loyalty (floor 0); a hero left under 20 is
  captured by the defender, if the defender's Feasting Hall has room (room?). Returns {loyalty, captured?}.
  """
  def after_lost_attack(loyalty, room?) do
    left = max(0, loyalty - @lost_attack_loyalty)
    {left, room? and left < @capture_below}
  end

  @doc """
  Takes back every point the player spent on the hero (added) as unspent points, for level x 1,000 gold, once a
  day. Points spent before this was tracked can't come back. Returns {:ok, changes, gold} or {:error, code}.
  """
  def check_reset(hero, now_ms, gold) do
    added = hero.added || %{}
    back = Enum.sum(Map.values(added))
    cost = fee(hero.level)

    cond do
      hero.status == "captive" ->
        {:error, "hero_busy"}

      back == 0 ->
        {:error, "nothing_to_reset"}

      hero.reset_at && now_ms < hero.reset_at + @reset_cooldown_ms ->
        {:error, "reset_cooldown"}

      gold < cost ->
        {:error, "not_enough_resources"}

      true ->
        {:ok,
         [
           points: hero.points + back,
           politics: hero.politics - Map.get(added, "politics", 0),
           attack: hero.attack - Map.get(added, "attack", 0),
           intelligence: hero.intelligence - Map.get(added, "intelligence", 0),
           added: %{}
         ], cost}
    end
  end
end
