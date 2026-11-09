defmodule Age3.Pvp do
  # Attacking other players' cities, as pure functions (no database), like Age3.March and Age3.Npc. The rules are
  # in plans/capture-loyalty-plan.md (project files) with TJ's answers of 2026-11-03:
  #
  #   * Any player city can be attacked: there is no beginner's protection for now.
  #   * The defending city fights with its troops if its gate is open (or its loyalty is 5 or less: closed gates
  #     open by themselves then), its walls, its owner's research and its defending hero (set apart from the
  #     mayor). Player cities have no fortifications yet.
  #   * A win plunders what the warehouses don't protect (gold is never protected; Privateering cuts the
  #     protection by 3% a level, wiki: capacity x 0.97^level), takes 3 loyalty and adds 2 grievance.
  #   * A win that arrives when the city's loyalty is already 0 captures it, if the attacker holds fewer than 10
  #     cities. A player's last city can be captured too: they get a new empty city.
  @moduledoc false

  alias Age3.{Combat, Data, Economy, Research}

  # (tunable) loyalty a winning attack takes (TJ, 2026-11-03: flat 3)
  @loyalty_per_win 3
  # (tunable) grievance a lost defence adds (the wiki says losing attacks raises it, without a number)
  @grievance_per_loss 2
  # at or below this loyalty a closed gate opens by itself (Evony For Dummies capture guide)
  @gate_opens_at 5
  # (tunable) the most cities a player can hold; titles don't limit it yet (TJ, 2026-11-03: flat 10)
  @city_cap 10
  # (tunable) a captured city's loyalty under its new owner
  @captured_loyalty 10

  def city_cap, do: @city_cap
  def captured_loyalty, do: @captured_loyalty

  @doc """
  What a march to a tile attacks. city is the player city standing on it (or nil), tile World.tile_at's
  %{kind, level}, player_id the attacker. {:city, city} | {:npc, level} | {:lord, level} | {:historic, level} |
  {:error, code}.
  """
  def target(%{player_id: owner} = city, _tile, player_id),
    do: if(owner == player_id, do: {:error, "own_city"}, else: {:city, city})

  def target(nil, %{kind: "npc", level: level}, _player_id), do: {:npc, level}
  # a made-up lord's town with no real player in it (Age3.Lord): fought like an NPC
  def target(nil, %{kind: "city", level: level}, _player_id), do: {:lord, level}

  # a historic city (Age3.Historic): fought like an NPC with its own garrison and ruler, never captured for now
  def target(nil, %{kind: "historic", level: level}, _player_id), do: {:historic, level}
  def target(nil, _tile, _player_id), do: {:error, "bad_target"}

  @doc "Does the garrison fight? Yes with the gate open, or once loyalty is low enough that it opens by itself."
  def gate_open?(gate_open, loyalty), do: gate_open or loyalty <= @gate_opens_at

  @doc """
  The battle engine's defender, fortifications and settings for a player city: its troops (if the gate is open),
  the owner's research as it counts in this city, its defending hero (a %{level, attack, intelligence,
  leadership, stars} map or nil) and its walls level.
  """
  def battle(troops, tech, hero, walls, open?) do
    defender = %{
      Combat.default_army()
      | troops: troops,
        tech: tech,
        hero: hero || Combat.default_army().hero,
        heal_percent: 0
    }

    {defender, %{}, %{Combat.default_settings() | walls: walls, closed_gates: not open?, npc: false}}
  end

  @doc "The defender's troops after the battle: the survivors, or all of them if they stayed behind the gate."
  def troops_left(troops, result, open?) do
    if open? do
      survived = for t <- result.defender.troops, into: %{}, do: {t.type, t.survived}
      Map.new(troops, fn {t, _n} -> {t, Map.get(survived, t, 0)} end)
    else
      troops
    end
  end

  @doc """
  What a winning army can take from a city: everything above what its warehouses protect, for food, lumber, stone
  and iron, and all its gold. amounts is %{"food" => 1234.5, ...}; buildings and research are the defender's;
  privateering the attacker's Privateering level. Whole numbers, rounded down.
  """
  def plunderable(amounts, buildings, research, privateering) do
    protected = (Economy.cap(buildings, research) - Data.base()["cap"]) * :math.pow(0.97, privateering)

    Map.new(amounts, fn
      {"gold", v} -> {"gold", max(0, trunc(v))}
      {k, v} -> {k, max(0, trunc(v - protected))}
    end)
  end

  @doc "The attacker's Privateering level, as it counts in the city the march left from."
  def privateering(research), do: Research.level_of(research, "privateering")

  @doc """
  A city's loyalty and grievance after a battle it lost (won by the attacker), and whether that win captures it.
  loyalty is the loyalty when the attack arrived; cities how many the attacker holds now. Returns %{loyalty,
  grievance, captured}.
  """
  def after_loss(loyalty, grievance, cities) do
    %{
      loyalty: max(0, loyalty - @loyalty_per_win),
      grievance: min(100, grievance + @grievance_per_loss),
      captured: loyalty == 0 and cities < @city_cap
    }
  end
end
