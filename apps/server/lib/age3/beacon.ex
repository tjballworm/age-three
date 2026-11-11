defmodule Age3.Beacon do
  # What a city's Beacon Tower tells it about another lord's march coming its way (the wiki's Beacon tower page),
  # as a pure function: Lv1 that it is coming, Lv2 its mission, Lv3 when it arrives, Lv4 which lord sent it, Lv5
  # where from, Lv6 the troop types, Lv7 rough numbers (2 significant figures, like a scout's estimate), Lv8 exact
  # numbers, Lv9 the hero's level, Lv10 the lord's research. Without a Beacon Tower nothing is known until it hits.
  @moduledoc false

  alias Age3.Scout

  @doc """
  What the city sees of one incoming march, as the client's IncomingMarch (camelCase keys), or nil without a
  Beacon Tower. march is %{id, mission, arrives_at (ms), lord, from: %{x, y, name}, troops, hero_level,
  research}.
  """
  def seen(level, _march) when level < 1, do: nil

  def seen(level, m) do
    [
      {1, :id, m.id},
      {2, :mission, m.mission},
      {3, :arrivesAt, m.arrives_at},
      {4, :from, m.lord},
      {5, :fromCity, m.from},
      {6, :troops, troops(level, m.troops)},
      {9, :heroLevel, m.hero_level},
      {10, :research, m.research}
    ]
    |> Enum.filter(fn {need, _k, _v} -> level >= need end)
    |> Map.new(fn {_need, k, v} -> {k, v} end)
  end

  # Lv6 types only (counts null), Lv7 rounded, Lv8 exact
  defp troops(level, troops) do
    detail =
      cond do
        level >= 8 -> :exact
        level >= 7 -> :approx
        true -> :basic
      end

    for {t, n} <- troops || %{}, n > 0, into: %{}, do: {t, Scout.shown(n, detail)}
  end
end
