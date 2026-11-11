defmodule Age3.Honor do
  # Honor from player battles, as pure functions (the wiki's Honor page; the exact formula isn't known, so the
  # divisor is ours and tunable). Each side gains or loses the difference between what the enemy lost and what it
  # lost, in the resources those troops cost to train / 1,000. It can't fall below 0. Battles with NPCs give none.
  # Prestige isn't earned from anything yet: TJ is reworking it.
  @moduledoc false

  alias Age3.Data

  @divisor 1_000

  @doc "A player battle's honor change for one side."
  def change(own_lost, enemy_lost), do: div(troop_value(enemy_lost) - troop_value(own_lost), @divisor)

  @doc "The resources these troops (%{type => n}) cost to train."
  def troop_value(troops),
    do: Enum.sum(for {t, n} <- troops || %{}, spec = Data.troop(t), do: n * total(spec["cost"]))

  @doc "The troops each side lost in a battle result: {attacker's, defender's}, as %{type => n}."
  def losses(result), do: {lost(result.attacker.troops), lost(result.defender.troops)}

  defp lost(troops), do: for(t <- troops, t.lost > 0, into: %{}, do: {t.type, t.lost})

  defp total(cost), do: cost |> Map.values() |> Enum.sum()
end
