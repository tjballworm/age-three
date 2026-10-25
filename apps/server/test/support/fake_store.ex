defmodule Age3.FakeStore do
  # A store with no database, for the session tests.
  @moduledoc false
  @behaviour Age3.Store

  @impl true
  def login(_name), do: {:ok, "p1"}

  @impl true
  def state(id), do: {:ok, %{id: id, name: "Lord TJ"}, []}
end
