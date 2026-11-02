defmodule Age3.Session do
  # One connected client's messages (like internal/session). Every message is
  # {"type": ..., "id": ..., "payload": {...}}, matching packages/protocol.
  #
  # This module only works with data: receive/2 takes the session and one raw message, and returns the reply
  # and the updated session. It never touches the socket, so tests can call it directly.
  @moduledoc false
  require Logger

  @version 1

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

  # Logging in: "login" with a username and password, or "hello" with the token from an earlier login.
  # Both answer "welcome"; only "login" includes a new token.

  defp handle(type, %{"version" => version}, id, session)
       when type in ["login", "hello"] and version != @version do
    {error(id, "version_mismatch", "Server speaks a different protocol version."), session}
  end

  defp handle("login", %{"version" => @version, "username" => name, "password" => password}, id, session)
       when is_binary(name) and is_binary(password) do
    case session.store.authenticate(String.trim(name), password) do
      {:ok, player_id} -> welcome(id, player_id, session.store.new_token(player_id), session)
      :error -> {error(id, "bad_login", "Wrong username or password."), session}
    end
  end

  defp handle("hello", %{"version" => @version, "token" => token}, id, session) when is_binary(token) do
    case session.store.player_for_token(token) do
      {:ok, player_id} -> welcome(id, player_id, nil, session)
      :error -> {error(id, "session_expired", "Please log in again."), session}
    end
  end

  defp handle(type, _payload, id, session) when type in ["login", "hello"] do
    {error(id, "bad_message", "Not a valid #{type}."), session}
  end

  defp handle("ping", %{"at" => at}, id, session) when is_integer(at),
    do: {reply(id, "pong", %{at: at, serverTime: session.now.()}), session}

  defp handle("ping", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid ping."), session}

  defp handle("getState", _payload, id, %{player_id: nil} = session),
    do: {error(id, "not_logged_in", "Log in first."), session}

  defp handle("getState", _payload, id, session) do
    # one clock reading: resources are settled to exactly the serverTime the client projects from
    now = session.now.()

    case session.store.state(session.player_id, now) do
      {:ok, player, cities} ->
        {reply(id, "state", %{player: player, cities: cities, serverTime: now}), session}

      {:error, :not_found} ->
        {error(id, "not_logged_in", "Player not found."), session}
    end
  end

  defp handle(_type, _payload, id, session),
    do: {error(id, "bad_message", "Unknown message type."), session}

  defp welcome(id, player_id, token, session) do
    payload = %{version: @version, playerId: player_id, serverTime: session.now.()}
    payload = if token, do: Map.put(payload, :token, token), else: payload
    {reply(id, "welcome", payload), %{session | player_id: player_id}}
  end

  # Replies carry the request's id so the client can match them up; id is left out when there was none.
  defp reply(id, type, payload) do
    msg = %{type: type, payload: payload}
    if is_integer(id), do: Map.put(msg, :id, id), else: msg
  end

  defp error(id, code, message), do: reply(id, "error", %{code: code, message: message})
end
