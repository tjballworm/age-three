defmodule Age3Web.GameSocket do
  # One open WebSocket. Each connection runs in its own lightweight BEAM process (like the goroutine per
  # connection in Go), and the callbacks below are called in that process one at a time, so there is no
  # write lock to manage. The process's state is the Age3.Session.
  @moduledoc false
  @behaviour WebSock

  @heartbeat 30_000

  @impl true
  def init(_opts) do
    schedule_ping()
    {:ok, Age3.Session.new()}
  end

  # A text frame from the client: one message in, one reply out.
  @impl true
  def handle_in({raw, opcode: :text}, session) do
    {reply, next} = Age3.Session.receive(session, raw)
    if next.player_id != session.player_id, do: listen_as(session.player_id, next.player_id)
    {:push, {:text, Jason.encode!(reply)}, next}
  end

  def handle_in({_raw, opcode: :binary}, session) do
    {reply, session} = Age3.Session.receive(session, "")
    {:push, {:text, Jason.encode!(reply)}, session}
  end

  # The browser answers pings with pongs on its own. A pong counts as traffic, so live connections never hit
  # the idle timeout set in SocketController; dead ones do, and get closed.
  @impl true
  def handle_control(_frame, session), do: {:ok, session}

  # Messages sent to this process: the ping timer, and finished tasks.
  @impl true
  def handle_info(:ping, session) do
    schedule_ping()
    {:push, {:ping, ""}, session}
  end

  # One of this player's tasks finished (from Age3.TaskRunner): push it with the new state.
  def handle_info({:task_done, task}, session) do
    case Age3.Session.task_done(session, task) do
      nil -> {:ok, session}
      push -> {:push, {:text, Jason.encode!(push)}, session}
    end
  end

  def handle_info(_msg, session), do: {:ok, session}

  @impl true
  def terminate(_reason, _session), do: :ok

  # After login, register under the player's id so the task runner can find this socket. The registry drops the
  # entry by itself when the connection closes.
  defp listen_as(old, new) do
    if old, do: Registry.unregister(Age3.Players, old)
    if new, do: Registry.register(Age3.Players, new, nil)
  end

  defp schedule_ping, do: Process.send_after(self(), :ping, @heartbeat)
end
