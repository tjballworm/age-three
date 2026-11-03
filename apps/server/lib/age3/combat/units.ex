defmodule Age3.Combat.Units do
  # Troop and fortification base stats for battles (Age II values, from the Evony Wiki troop table). A copy of
  # packages/core/src/combat/units.ts; the parity test (test/age3/combat_test.exs) fails if the two disagree.
  @moduledoc false

  # Catalogue order is also the final tiebreak everywhere in the battle engine.
  @troops ~w(worker warrior scout pike sword archer cavalry cataphract transporter ballista ram catapult)
  @forts ~w(trap abatis tower log trebuchet)

  @stats %{
    "worker" => %{name: "Workers", life: 100, attack: 5, defence: 10, speed: 180, range: 10},
    "warrior" => %{name: "Warriors", life: 200, attack: 50, defence: 50, speed: 200, range: 20},
    "scout" => %{name: "Scouts", life: 100, attack: 20, defence: 20, speed: 3000, range: 20},
    "pike" => %{name: "Pikemen", life: 300, attack: 150, defence: 150, speed: 300, range: 50},
    "sword" => %{name: "Swordsmen", life: 350, attack: 100, defence: 250, speed: 275, range: 30},
    "archer" => %{name: "Archers", life: 250, attack: 120, defence: 50, speed: 250, range: 1200},
    "cavalry" => %{name: "Cavalry", life: 500, attack: 250, defence: 180, speed: 1000, range: 100},
    "cataphract" => %{name: "Cataphracts", life: 1000, attack: 350, defence: 350, speed: 750, range: 80},
    "transporter" => %{name: "Transporters", life: 700, attack: 10, defence: 60, speed: 150, range: 10},
    "ballista" => %{name: "Ballistae", life: 320, attack: 450, defence: 160, speed: 100, range: 1400},
    "ram" => %{name: "Battering rams", life: 5000, attack: 250, defence: 160, speed: 120, range: 600},
    "catapult" => %{name: "Catapults", life: 480, attack: 600, defence: 200, speed: 80, range: 1500}
  }

  @fort_name %{
    "trap" => "Traps",
    "abatis" => "Abatis",
    "tower" => "Archer towers",
    "log" => "Rolling logs",
    "trebuchet" => "Defensive trebuchets"
  }

  # base range of each fortification; used only for the starting battlefield distance (and tower reach)
  @fort_range %{"trap" => 5000, "abatis" => 5000, "tower" => 1300, "log" => 1300, "trebuchet" => 5000}

  def troops, do: @troops
  def forts, do: @forts
  def stats(type), do: Map.fetch!(@stats, type)
  def fort_name(fort), do: Map.fetch!(@fort_name, fort)
  def fort_range(fort), do: Map.fetch!(@fort_range, fort)

  def tower, do: %{attack: 300, defence: 360, life: 2000, range: 1300}

  @doc "Troops that shoot. Archer towers are ranged too."
  def ranged?(type), do: type in ~w(archer ballista catapult)

  @doc "Compass speeds up infantry and scouts; Horseback Riding speeds up everything else."
  def compass?(type), do: type in ~w(worker warrior scout pike sword archer)

  @doc "Order hero Leadership capacity is handed out in."
  def hero_coverage_order,
    do: ~w(catapult ram ballista cataphract cavalry archer sword pike warrior scout worker transporter)

  def trap_targets, do: ~w(worker warrior scout pike sword archer cavalry cataphract)
  def log_targets, do: ~w(worker warrior pike sword scout archer)
  def abatis_targets, do: ~w(cavalry cataphract)

  @doc "Gear stars -> life and leadership multipliers."
  def star_multipliers(stars) when stars >= 15, do: %{life: 3.5, leadership: 3.0}
  def star_multipliers(stars) when stars >= 14, do: %{life: 2.8, leadership: 2.7}
  def star_multipliers(stars) when stars >= 12, do: %{life: 2.5, leadership: 2.5}
  def star_multipliers(stars) when stars >= 9, do: %{life: 2.0, leadership: 2.0}
  def star_multipliers(stars) when stars >= 5, do: %{life: 1.4, leadership: 1.5}
  def star_multipliers(_stars), do: %{life: 1.0, leadership: 1.0}

  @doc "Damage multiplier for an ordinary troop attack against a troop target."
  def counter("pike", target) when target in ["cavalry", "cataphract"], do: 1.8
  def counter(attacker, "archer") when attacker in ["cavalry", "cataphract"], do: 1.2
  def counter("sword", "pike"), do: 1.1
  def counter(_attacker, _target), do: 1
end
