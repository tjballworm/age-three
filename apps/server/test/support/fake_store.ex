defmodule Age3.FakeStore do
  # A store with no database, for the session tests. One account: "Lord TJ" with password "secret123".
  @moduledoc false
  @behaviour Age3.Store

  @impl true
  def authenticate("Lord TJ", "secret123"), do: {:ok, "p1"}
  def authenticate(_name, _password), do: :error

  @impl true
  def new_token("p1"), do: "t1"

  @impl true
  def player_for_token("t1"), do: {:ok, "p1"}
  def player_for_token(_token), do: :error

  @impl true
  def state(id, _now_ms), do: {:ok, %{id: id, name: "Lord TJ"}, []}
end
