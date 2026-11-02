defmodule Age3.TaskRunner do
  # Finishes tasks when they end and tells the players. One process for the whole server: it sleeps until the
  # next task is due (or a minute at most), finishes everything due, and sends {:task_done, task} to each
  # owner's open sockets, found through the Age3.Players registry.
  #
  # It is only the live part. Age3.Store.Pg.state/2 also finishes due tasks, so nothing is lost while this
  # process is restarting or a deploy is under way.
  @moduledoc false
  use GenServer
  require Logger

  alias Age3.{Session, Store}

  @max_sleep 60_000
  @retry_after_error 5_000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "A task will end at ends_at_ms: wake up for it if that is sooner than planned. A no-op when not running."
  def wake(ends_at_ms) do
    if pid = Process.whereis(__MODULE__), do: send(pid, {:wake, ends_at_ms})
    :ok
  end

  @impl true
  def init(_opts), do: {:ok, %{timer: nil, at: nil}, {:continue, :run}}

  # straight after start: anything that ended while the server was down
  @impl true
  def handle_continue(:run, state), do: {:noreply, run(state)}

  @impl true
  def handle_info(:run, state), do: {:noreply, run(state)}

  def handle_info({:wake, ends_at}, state) do
    if state.at == nil or ends_at < state.at,
      do: {:noreply, schedule(state, ends_at)},
      else: {:noreply, state}
  end

  defp run(state) do
    now = Session.millis()

    for {player_id, task} <- Store.Pg.finish_due(now) do
      Registry.dispatch(Age3.Players, player_id, fn sockets ->
        for {pid, _} <- sockets, do: send(pid, {:task_done, task})
      end)
    end

    schedule(state, min(Store.Pg.next_due() || now + @max_sleep, now + @max_sleep))
  rescue
    e ->
      Logger.error("task runner: " <> Exception.format(:error, e, __STACKTRACE__))
      schedule(state, Session.millis() + @retry_after_error)
  end

  defp schedule(state, at) do
    if state.timer, do: Process.cancel_timer(state.timer)
    delay = max(0, at - Session.millis())
    %{state | timer: Process.send_after(self(), :run, delay), at: at}
  end
end
