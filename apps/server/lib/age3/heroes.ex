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
  {:error, "bad_message"} / {:error, "not_enough_points"}.
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

        {:ok,
         [
           points: hero.points - p - a - i,
           politics: hero.politics + p,
           attack: hero.attack + a,
           intelligence: hero.intelligence + i
         ]}
    end
  end
end
