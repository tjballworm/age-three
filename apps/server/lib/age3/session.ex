defmodule Age3.Session do
  # One connected client's messages (like internal/session). Every message is
  # {"type": ..., "id": ..., "payload": {...}}, matching packages/protocol.
  #
  # This module only works with data: receive/2 takes the session and one raw message, and returns the reply
  # and the updated session. It never touches the socket, so tests can call it directly.
  @moduledoc false
  require Logger

  @version 1
  @valid_name ~r/^[A-Za-z0-9 _'-]{3,24}$/

  defstruct store: Age3.Store.Pg, player_id: nil, now: &__MODULE__.millis/0

  def version, do: @version
  def millis, do: System.system_time(:millisecond)

  def new(opts \\ []), do: struct!(__MODULE__, opts)

  @doc "Handles one raw message. Returns {reply, session}; the reply is a map ready to encode as JSON."
  def receive(session, raw) do
    case Jason.decode(raw) do
      {:ok, %{"type" => type, "payload" => %{} = payload} = msg} when is_binary(type) and type != "" ->
        id = msg["id"]

        try do
          handle(type, payload, id, session)
        rescue
          e ->
            Logger.error("session: #{type}: " <> Exception.format(:error, e, __STACKTRACE__))
            {error(id, "server_error", "Something went wrong on the server."), session}
        end

      _ ->
        {error(nil, "bad_message", "Not a valid message."), session}
    end
  end

  # One clause per message type. Elixir picks the first clause whose pattern matches the arguments.

  defp handle("hello", %{"version" => version, "name" => name}, id, session)
       when is_integer(version) and is_binary(name) do
    name = String.trim(name)

    cond do
      version != @version ->
        {error(id, "version_mismatch", "Server speaks a different protocol version."), session}

      not Regex.match?(@valid_name, name) ->
        {error(id, "bad_message", "Name must be 3–24 letters, numbers or spaces."), session}

      true ->
        case session.store.login(name) do
          {:ok, player_id} ->
            payload = %{version: @version, playerId: player_id, serverTime: session.now.()}
            {reply(id, "welcome", payload), %{session | player_id: player_id}}

          {:error, reason} ->
            raise "login failed: #{inspect(reason)}"
        end
    end
  end

  defp handle("hello", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid hello."), session}

  defp handle("ping", %{"at" => at}, id, session) when is_integer(at),
    do: {reply(id, "pong", %{at: at, serverTime: session.now.()}), session}

  defp handle("ping", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid ping."), session}

  defp handle("getState", _payload, id, %{player_id: nil} = session),
    do: {error(id, "not_logged_in", "Say hello first."), session}

  defp handle("getState", _payload, id, session) do
    case session.store.state(session.player_id) do
      {:ok, player, cities} ->
        {reply(id, "state", %{player: player, cities: cities, serverTime: session.now.()}), session}

      {:error, :not_found} ->
        {error(id, "not_logged_in", "Player not found."), session}
    end
  end

  defp handle(_type, _payload, id, session),
    do: {error(id, "bad_message", "Unknown message type."), session}

  # Replies carry the request's id so the client can match them up; id is left out when there was none.
  defp reply(id, type, payload) do
    msg = %{type: type, payload: payload}
    if is_integer(id), do: Map.put(msg, :id, id), else: msg
  end

  defp error(id, code, message), do: reply(id, "error", %{code: code, message: message})
end
