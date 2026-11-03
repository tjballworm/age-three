defmodule Age3.Cheats do
  # Testing commands ("cheat" messages): give resources, troops and population, finish everything at once, set
  # building and research levels, reset a city. Pure functions only (no database), like Age3.Build; the
  # database side is Age3.Store.Pg.cheat/5.
  #
  # There is NO gating: any logged-in player can cheat, on their own cities or on any account by username. That
  # is on purpose while the game is in testing. To turn cheats off later, make enabled?/0 read a config value.
  @moduledoc false

  alias Age3.{Build, Data}

  @resources ~w(gold food lumber stone iron)
  # the most a single cheat can add or take away of one resource or troop, so a typo can't overflow anything
  @max_amount 1_000_000_000_000
  # (tunable) the highest a hero stat or unspent points can be set to
  @max_hero_stat 9_999
  # gear stars: the battle multipliers stop growing at 15 (Combat.Units.star_multipliers)
  @max_stars 15
  @hero_fields [
    {"level", :level},
    {"points", :points},
    {"politics", :politics},
    {"attack", :attack},
    {"intelligence", :intelligence},
    {"stars", :stars}
  ]

  @doc "Whether cheat messages are accepted. Always true for now (see the note at the top)."
  def enabled?, do: true

  @doc """
  Checks a cheat message's fields for one action. Returns {:ok, args} with the values the store needs, or
  {:error, "bad_message"}.

    * "addResources" {amounts: {gold, food, lumber, stone, iron}}: adds each (negative takes away, not below 0)
    * "fillResources": every resource up to the storage limit
    * "addTroops" {troops: {warrior: 100, ...}}: adds troops (negative takes away, not below 0)
    * "setPopulation" {amount}: the population, from 0 up to the city's limit
    * "finishAll": every construction, research and training batch in the city finishes now
    * "setBuilding" {slot, type?, level}: the building on a slot at any level for free; level 0 removes it
    * "levelAll" {level}: every building and field in the city at that level
    * "setResearch" {tech, level} / "researchAll" {level}: research levels for the player (0 forgets them)
    * "heroExp" {amount}: exp for every hero in the city (they level up as it covers)
    * "setHero" {heroId, level?, points?, politics?, attack?, intelligence?, stars?}: one hero's level, stats and
      gear stars (0-15), set
      straight (only the fields sent change; a new level starts with 0 exp). The hero has to be in the target's
      cities.
    * "addMedals" {medals: {cross: 10, ...}}: adds medals to the player (negative takes away, not below 0)
    * "setTitle" {rank?, title?}: the player's rank and/or title, set straight with nothing paid
    * "setLoyalty" {loyalty?, grievance?}: the city's loyalty and/or public grievance (0-100), set straight; the
      comfort cooldown is cleared too
    * "resetCity": back to a new city (Town Hall and walls Lv1, starting resources, no troops, heroes or tasks)
  """
  def parse("addResources", %{"amounts" => %{} = amounts}) do
    if Enum.all?(amounts, fn {k, v} -> k in @resources and amount?(v) end),
      do: {:ok, %{amounts: amounts}},
      else: bad()
  end

  def parse("addTroops", %{"troops" => %{} = troops}) do
    if Enum.all?(troops, fn {k, v} -> Data.troop(k) != nil and amount?(v) end),
      do: {:ok, %{troops: troops}},
      else: bad()
  end

  def parse("setPopulation", %{"amount" => n}) when is_integer(n) and n >= 0, do: {:ok, %{amount: n}}

  def parse("setBuilding", %{"slot" => slot, "level" => level} = p) when is_integer(level) do
    type = p["type"]

    cond do
      slot_key(slot) == nil -> bad()
      level not in 0..Data.max_level() -> bad()
      type != nil and Data.building(type) == nil -> bad()
      true -> {:ok, %{slot: slot_key(slot), type: type, level: level}}
    end
  end

  def parse("heroExp", %{"amount" => n}) when is_integer(n) and n > 0 and n <= @max_amount,
    do: {:ok, %{amount: n}}

  def parse("setHero", %{"heroId" => hero_id} = p) when is_binary(hero_id) do
    changes =
      for {key, field} <- @hero_fields, Map.has_key?(p, key), do: {field, p[key]}

    cond do
      changes == [] -> bad()
      not Enum.all?(changes, fn {field, v} -> hero_value?(field, v) end) -> bad()
      # a new level starts from 0 exp, so the old exp can't be more than the new level needs
      Keyword.has_key?(changes, :level) -> {:ok, %{hero_id: hero_id, changes: [{:exp, 0} | changes]}}
      true -> {:ok, %{hero_id: hero_id, changes: changes}}
    end
  end

  def parse("levelAll", %{"level" => level}) when is_integer(level) do
    if level in 1..Data.max_level(), do: {:ok, %{level: level}}, else: bad()
  end

  def parse("setResearch", %{"tech" => tech, "level" => level}) when is_integer(level) do
    if Data.tech(tech) != nil and level in 0..Data.max_tech_level(),
      do: {:ok, %{tech: tech, level: level}},
      else: bad()
  end

  def parse("researchAll", %{"level" => level}) when is_integer(level) do
    if level in 0..Data.max_tech_level(), do: {:ok, %{level: level}}, else: bad()
  end

  def parse("addMedals", %{"medals" => %{} = medals}) do
    if medals != %{} and Enum.all?(medals, fn {k, v} -> k in Data.medal_ids() and amount?(v) end),
      do: {:ok, %{medals: medals}},
      else: bad()
  end

  def parse("setTitle", p) do
    changes =
      for {key, field, ladder} <- [{"rank", :military_rank, :rank}, {"title", :title, :title}],
          Map.has_key?(p, key),
          do: {field, ladder, p[key]}

    if changes != [] and Enum.all?(changes, fn {_f, ladder, id} -> Age3.Titles.spec(ladder, id) != nil end),
      do: {:ok, %{changes: for({field, _l, id} <- changes, do: {field, id})}},
      else: bad()
  end

  def parse("setLoyalty", p) do
    changes = for k <- ["loyalty", "grievance"], Map.has_key?(p, k), do: {String.to_atom(k), p[k]}

    if changes != [] and Enum.all?(changes, fn {_k, v} -> is_integer(v) and v in 0..100 end),
      do: {:ok, %{changes: changes}},
      else: bad()
  end

  def parse("instantMarch", %{"on" => on}) when is_boolean(on), do: {:ok, %{on: on}}

  def parse(action, _payload) when action in ["fillResources", "finishAll", "resetCity"], do: {:ok, %{}}
  def parse(_action, _payload), do: bad()

  @doc "Whether the action changes the player's research rather than a city."
  def research?(action), do: action in ["setResearch", "researchAll"]

  @doc "Adds amounts (%{\"gold\" => 1000, ...}) to settled resources; nothing goes below 0."
  def add_resources(resources, amounts) do
    Map.new(resources, fn {name, stock} ->
      {name, %{stock | "amount" => max(0, stock["amount"] + Map.get(amounts, name, 0))}}
    end)
  end

  @doc "Every resource up to its storage limit (one already over it stays put)."
  def fill_resources(resources) do
    Map.new(resources, fn {name, stock} ->
      {name, %{stock | "amount" => max(stock["amount"], stock["cap"])}}
    end)
  end

  @doc "Adds troop counts to a city's troops; none go below 0, and types that reach 0 are dropped."
  def add_troops(troops, more) do
    Enum.reduce(more, troops || %{}, fn {troop, n}, acc ->
      case max(0, Map.get(acc, troop, 0) + n) do
        0 -> Map.delete(acc, troop)
        total -> Map.put(acc, troop, total)
      end
    end)
  end

  @doc """
  What setBuilding does to a slot, given the city's buildings: {:remove} for level 0, {:set, type} to put type
  there at the level, or {:error, code}. Leaving out type keeps what stands there. The building has to fit the
  slot (fields in the outskirts, the Town Hall on its spot...), the Town Hall can't be removed, and a one-per-city
  building can't be put on a second slot. Requirements and the Town Hall level are ignored.
  """
  def place(buildings, slot, type, level) do
    current = Enum.find(buildings, &(&1.slot == slot))
    type = type || (current && current.type)

    cond do
      level == 0 and current == nil -> {:error, "bad_slot"}
      level == 0 and slot == "townhall" -> {:error, "bad_slot"}
      level == 0 -> {:remove}
      type == nil or not Build.fits?(slot, type) -> {:error, "bad_slot"}
      taken?(buildings, slot, type) -> {:error, "requirement_not_met"}
      true -> {:set, type}
    end
  end

  @doc "Research levels with tech at level (0 drops it)."
  def set_research(research, tech, 0), do: Map.delete(research || %{}, tech)
  def set_research(research, tech, level), do: Map.put(research || %{}, tech, level)

  @doc "Every tech at level (0 forgets all research)."
  def all_research(0), do: %{}
  def all_research(level), do: Map.new(Data.tech_ids(), &{&1, level})

  defp taken?(buildings, slot, type) do
    not Data.building(type)["multiple"] and Enum.any?(buildings, &(&1.type == type and &1.slot != slot))
  end

  defp hero_value?(:level, v), do: is_integer(v) and v in 1..Age3.Heroes.max_level()
  defp hero_value?(:stars, v), do: is_integer(v) and v in 0..@max_stars
  defp hero_value?(_stat, v), do: is_integer(v) and v in 0..@max_hero_stat

  defp amount?(v), do: is_integer(v) and abs(v) <= @max_amount

  defp slot_key(slot) when is_integer(slot) and slot in 0..31, do: Integer.to_string(slot)
  defp slot_key(slot) when slot in ["townhall", "walls"], do: slot
  defp slot_key("f" <> n = slot), do: if(match?({_, ""}, Integer.parse(n)), do: slot, else: nil)
  defp slot_key(_slot), do: nil

  defp bad, do: {:error, "bad_message"}
end
