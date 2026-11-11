defmodule Age3.Items do
  # Items as pure functions (priv/data/items.json, after the wiki's item lists). Speed-ups take time off a running
  # or waiting task of the kinds they name (a set amount, or a share of the time left); resource items add to the
  # city they are used in. The shop sells them for gold for now (no paid currency yet).
  @moduledoc false

  alias Age3.Data

  @max_buy 1_000

  @doc "The gold for count of an item from the shop, or an error (not for sale, bad count)."
  def price(id, count) do
    case Data.item(id) do
      %{"price" => p} when p > 0 and is_integer(count) and count in 1..@max_buy -> {:ok, p * count}
      _ -> {:error, "bad_message"}
    end
  end

  @doc "Takes count of an item from a player's items. {:ok, items} or {:error, \"no_item\"}."
  def take(items, id, count \\ 1) do
    have = Map.get(items || %{}, id, 0)

    cond do
      have < count -> {:error, "no_item"}
      have == count -> {:ok, Map.delete(items, id)}
      true -> {:ok, Map.put(items, id, have - count)}
    end
  end

  @doc "Adds items (%{id => count}) to a player's items."
  def give(items, more), do: Map.merge(items || %{}, more || %{}, fn _k, a, b -> a + b end)

  @doc """
  A speed-up used on a task of kind ending at ends_ms (now_ms now): the new end, never before now. {:ok, ms} or
  {:error, "bad_message"} when the item doesn't fit the task.
  """
  def speed_up(id, kind, ends_ms, now_ms) do
    case Data.item(id) do
      %{"use" => %{"kinds" => kinds} = use} ->
        if kind in kinds do
          left = max(0, ends_ms - now_ms)
          cut = if use["speed"], do: use["speed"] * 1000, else: div(left * use["speedPercent"], 100)
          {:ok, max(now_ms, ends_ms - cut)}
        else
          {:error, "bad_message"}
        end

      _ ->
        {:error, "bad_message"}
    end
  end

  @doc "The resources a resource item gives, or nil for other items."
  def resources(id), do: get_in(Data.item(id) || %{}, ["use", "resources"])
end
