defmodule Age3.Prestige do
  # Prestige and honor as pure functions (the wiki's Prestige and Honor pages; the exact formulas aren't known,
  # so the divisors here are ours and tunable).
  #
  # Prestige: finishing a building, research, troops or fortifications gives "experience" = its resource cost
  # / 200, divided by the total of the player's Town Hall levels (rounded down). The wiki's examples fit that
  # (3 warriors = 1 prestige with a Lv3 Town Hall). In a battle each side gains the experience of the enemy troops
  # it killed and loses that of its own troops lost, the same way (it can't fall below 0).
  #
  # Honor (player battles only): each side gains or loses the difference between what the enemy lost and what it
  # lost, in resources / 1,000. It can't fall below 0.
  @moduledoc false

  alias Age3.Data

  @exp_divisor 200
  @honor_divisor 1_000

  @doc "Prestige for something that cost cost (%{\"food\" => n, ...}) with these Town Hall levels in total."
  def for_cost(cost, town_halls), do: div(trunc(total(cost) / @exp_divisor), max(1, town_halls))

  @doc "The resources these troops (%{type => n}) cost to train."
  def troop_value(troops),
    do: Enum.sum(for {t, n} <- troops || %{}, spec = Data.troop(t), do: n * total(spec["cost"]))

  @doc "A battle's prestige change for one side: the enemy troops it killed less its own lost, per Town Hall."
  def battle(own_lost, enemy_lost, town_halls),
    do:
      for_cost(%{"gold" => troop_value(enemy_lost)}, town_halls) -
        for_cost(%{"gold" => troop_value(own_lost)}, town_halls)

  @doc "A player battle's honor change for one side."
  def honor(own_lost, enemy_lost), do: div(troop_value(enemy_lost) - troop_value(own_lost), @honor_divisor)

  @doc "The troops each side lost in a battle result: {attacker's, defender's}, as %{type => n}."
  def losses(result), do: {lost(result.attacker.troops), lost(result.defender.troops)}

  defp lost(troops), do: for(t <- troops, t.lost > 0, into: %{}, do: {t.type, t.lost})

  defp total(cost), do: cost |> Map.values() |> Enum.sum()
end
