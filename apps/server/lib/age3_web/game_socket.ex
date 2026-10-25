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
    {reply, session} = Age3.Session.receive(session, raw)
    {:push, {:text, Jason.encode!(reply)}, session}
  end

  def handle_in({_raw, opcode: :binary}, session) do
    {reply, session} = Age3.Session.receive(session, "")
    {:push, {:text, Jason.encode!(reply)}, session}
  end

  # The browser answers pings with pongs on its own. A pong counts as traffic, so live connections never hit
  # the idle timeout set in SocketController; dead ones do, and get closed.
  @impl true
  def handle_control(_frame, session), do: {:ok, session}

  # Messages sent to this process (here, the ping timer; later, pushes like "build finished").
  @impl true
  def handle_info(:ping, session) do
    schedule_ping()
    {:push, {:ping, ""}, session}
  end

  def handle_info(_msg, session), do: {:ok, session}

  @impl true
  def terminate(_reason, _session), do: :ok

  defp schedule_ping, do: Process.send_after(self(), :ping, @heartbeat)
end
