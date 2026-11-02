defmodule Age3.Session do
  # One connected client's messages (like internal/session). Every message is
  # {"type": ..., "id": ..., "payload": {...}}, matching packages/protocol.
  #
  # This module only works with data: receive/2 takes the session and one raw message, and returns the reply
  # and the updated session. It never touches the socket, so tests can call it directly.
  @moduledoc false
  require Logger

  @version 1

  # wake is told when a new task will end, so the task runner can finish it on time
  defstruct store: Age3.Store.Pg, player_id: nil, now: &__MODULE__.millis/0, wake: &Age3.TaskRunner.wake/1

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

  defp handle(type, _payload, id, %{player_id: nil} = session)
       when type in ["getState", "build", "cancelBuild", "speedUp", "setTax"],
       do: {error(id, "not_logged_in", "Log in first."), session}

  defp handle("getState", _payload, id, session), do: state_reply(id, session, session.now.())

  # Build on a slot, or upgrade what stands there: {cityId, slot, type?}. Town plots are numbers 0-31, the
  # Town Hall and walls "townhall" and "walls", and outskirts fields "f0".."f12". Replies with the new state.
  defp handle("build", %{"cityId" => city_id, "slot" => slot} = payload, id, session)
       when is_binary(city_id) do
    now = session.now.()

    case session.store.build(session.player_id, city_id, slot_key(slot), payload["type"], now) do
      {:ok, ends_at} ->
        session.wake.(ends_at)
        state_reply(id, session, now)

      {:error, code} ->
        {error(id, code, message(code)), session}
    end
  end

  defp handle("build", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid build."), session}

  # Stop a construction and get its cost back: {cityId, taskId}.
  defp handle("cancelBuild", %{"cityId" => city_id, "taskId" => task_id}, id, session)
       when is_binary(city_id) and is_binary(task_id) do
    now = session.now.()

    case session.store.cancel_build(session.player_id, city_id, task_id, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("cancelBuild", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid cancel."), session}

  # Finish a build for free when it has 5 minutes or less left: {cityId, taskId}.
  defp handle("speedUp", %{"cityId" => city_id, "taskId" => task_id}, id, session)
       when is_binary(city_id) and is_binary(task_id) do
    now = session.now.()

    case session.store.speed_up(session.player_id, city_id, task_id, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("speedUp", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid speedup."), session}

  # Change a city's tax rate: {cityId, taxRate} with taxRate a whole number from 0 to 100.
  defp handle("setTax", %{"cityId" => city_id, "taxRate" => rate}, id, session)
       when is_binary(city_id) and is_integer(rate) and rate in 0..100 do
    now = session.now.()

    case session.store.set_tax(session.player_id, city_id, rate, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("setTax", _payload, id, session),
    do: {error(id, "bad_message", "The tax rate must be a whole number from 0 to 100."), session}

  defp handle(_type, _payload, id, session),
    do: {error(id, "bad_message", "Unknown message type."), session}

  @doc """
  The push for a finished task: the task plus the player's whole new state. nil if the state can't be read.
  GameSocket sends it when Age3.TaskRunner reports one of this player's tasks done.
  """
  def task_done(session, task) do
    now = session.now.()

    case session.store.state(session.player_id, now) do
      {:ok, player, cities, tasks} ->
        %{
          type: "taskDone",
          payload: %{task: task, player: player, cities: cities, tasks: tasks, serverTime: now}
        }

      {:error, _} ->
        nil
    end
  end

  # One clock reading: resources are settled to exactly the serverTime the client projects from.
  defp state_reply(id, session, now) do
    case session.store.state(session.player_id, now) do
      {:ok, player, cities, tasks} ->
        payload = %{player: player, cities: cities, tasks: tasks, serverTime: now}
        {reply(id, "state", payload), session}

      {:error, :not_found} ->
        {error(id, "not_logged_in", "Player not found."), session}
    end
  end

  defp slot_key(slot) when is_integer(slot), do: Integer.to_string(slot)
  defp slot_key(slot) when is_binary(slot), do: slot
  defp slot_key(_slot), do: nil

  defp message("not_enough_resources"), do: "Not enough resources."
  defp message("queue_busy"), do: "Something is already being built in this city."
  defp message("requirement_not_met"), do: "Requirements not met."
  defp message("bad_slot"), do: "That can't be built there."
  defp message("max_level"), do: "Already at the highest level."
  defp message("too_early"), do: "Speedup is only free in the last 5 minutes."
  defp message(_code), do: "Not a valid request."

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
