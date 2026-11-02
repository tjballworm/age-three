defmodule Age3.Economy do
  # Resources over time. A city stores a snapshot of its resources and when it was taken (cities.synced_at);
  # the server works out the amounts at any later moment from that, so nothing has to tick every second.
  @moduledoc false

  @hour 3_600_000

  @doc """
  Resources as they stand at now_ms, given the snapshot taken at since_ms (both epoch milliseconds).
  Matches stockAt in packages/core/src/rules/timing.ts: production stops at the cap (an amount already over it
  stays put), and amounts never go below zero. Only "amount" changes; it is a float, so no income is lost to
  rounding between settles.
  """
  @spec settle(map, integer, integer) :: map
  def settle(resources, since_ms, now_ms) do
    elapsed = max(0, now_ms - since_ms)
    Map.new(resources, fn {name, stock} -> {name, grow(stock, elapsed)} end)
  end

  defp grow(%{"amount" => amount, "perHour" => per_hour, "cap" => cap} = stock, elapsed) when per_hour > 0 do
    projected = amount + per_hour * elapsed / @hour
    %{stock | "amount" => max(amount, min(projected, max(cap, amount)))}
  end

  defp grow(%{"amount" => amount, "perHour" => per_hour} = stock, elapsed) do
    %{stock | "amount" => max(0, amount + per_hour * elapsed / @hour)}
  end
end
