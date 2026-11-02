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
  def state(id, _now_ms), do: {:ok, %{id: id, name: "Lord TJ"}, [], []}

  # slot "0" can always be built; anything else is busy
  @impl true
  def build(_player_id, _city_id, "0", _type, now_ms), do: {:ok, now_ms + 45_000}
  def build(_player_id, _city_id, _slot, _type, _now_ms), do: {:error, "queue_busy"}

  @impl true
  def cancel_build(_player_id, _city_id, "t1", _now_ms), do: :ok
  def cancel_build(_player_id, _city_id, _task_id, _now_ms), do: {:error, "bad_message"}
end
