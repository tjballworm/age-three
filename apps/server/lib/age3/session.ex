defmodule Age3.Session do
  # One connected client's messages (like internal/session). Every message is
  # {"type": ..., "id": ..., "payload": {...}}, matching packages/protocol.
  #
  # This module only works with data: receive/2 takes the session and one raw message, and returns the reply
  # and the updated session. It never touches the socket, so tests can call it directly.
  @moduledoc false
  require Logger

  @version 1

  # wake is told when a new task will end, so the task runner can finish it on time; notify is told when a cheat
  # changed another player's game, so their open sockets can show it
  defstruct store: Age3.Store.Pg,
            player_id: nil,
            now: &__MODULE__.millis/0,
            wake: &Age3.TaskRunner.wake/1,
            notify: &__MODULE__.notify/1

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
       when type in [
              "getState",
              "build",
              "cancelBuild",
              "speedUp",
              "setTax",
              "research",
              "cancelResearch",
              "train",
              "cancelTrain",
              "cheat"
            ],
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

  # Research the next level of a tech in the city's Academy: {cityId, tech}. Replies with the new state.
  defp handle("research", %{"cityId" => city_id, "tech" => tech}, id, session)
       when is_binary(city_id) and is_binary(tech) do
    now = session.now.()

    case session.store.research(session.player_id, city_id, tech, now) do
      {:ok, ends_at} ->
        session.wake.(ends_at)
        state_reply(id, session, now)

      {:error, code} ->
        {error(id, code, message(code)), session}
    end
  end

  defp handle("research", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid research."), session}

  # Stop a research and get its cost back: {cityId, taskId}.
  defp handle("cancelResearch", %{"cityId" => city_id, "taskId" => task_id}, id, session)
       when is_binary(city_id) and is_binary(task_id) do
    now = session.now.()

    case session.store.cancel_research(session.player_id, city_id, task_id, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("cancelResearch", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid cancel."), session}

  # Train troops in a Barracks: {cityId, slot, troop, count}, slot being the Barracks' town plot (0-31). The
  # batch joins the end of that Barracks' queue. Replies with the new state; the troops arrive with taskDone.
  defp handle(
         "train",
         %{"cityId" => city_id, "slot" => slot, "troop" => troop, "count" => count},
         id,
         session
       )
       when is_binary(city_id) and is_binary(troop) and is_integer(count) do
    now = session.now.()

    case session.store.train(session.player_id, city_id, slot_key(slot), troop, count, now) do
      {:ok, ends_at} ->
        session.wake.(ends_at)
        state_reply(id, session, now)

      {:error, code} ->
        {error(id, code, message(code)), session}
    end
  end

  defp handle("train", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid train."), session}

  # Stop a training batch and get its cost and people back: {cityId, taskId}. The batches behind it move up.
  defp handle("cancelTrain", %{"cityId" => city_id, "taskId" => task_id}, id, session)
       when is_binary(city_id) and is_binary(task_id) do
    now = session.now.()

    case session.store.cancel_train(session.player_id, city_id, task_id, now) do
      :ok ->
        # the next batch may now end sooner than the task runner planned for
        session.wake.(now)
        state_reply(id, session, now)

      {:error, code} ->
        {error(id, code, message(code)), session}
    end
  end

  defp handle("cancelTrain", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid cancel."), session}

  # Finish a build, research or the batch a Barracks is training for free when it has 5 minutes or less left:
  # {cityId, taskId}.
  defp handle("speedUp", %{"cityId" => city_id, "taskId" => task_id}, id, session)
       when is_binary(city_id) and is_binary(task_id) do
    now = session.now.()

    case session.store.speed_up(session.player_id, city_id, task_id, now) do
      :ok ->
        # a sped-up batch lets the next one in its Barracks start (and end) sooner
        session.wake.(now)
        state_reply(id, session, now)

      {:error, code} ->
        {error(id, code, message(code)), session}
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

  # A testing command (see Age3.Cheats): {action, cityId} for one of your cities, or {action, player} for every
  # city of any player by username, plus the action's fields. No permission check on purpose: every tester can
  # cheat, on any account. Replies with your own new state; another player's open game gets theirs pushed.
  defp handle("cheat", %{"action" => action} = payload, id, session) when is_binary(action) do
    now = session.now.()

    with true <- Age3.Cheats.enabled?() || {:error, "bad_message"},
         {:ok, target} <- cheat_target(payload),
         {:ok, args} <- Age3.Cheats.parse(action, payload),
         {:ok, target_id} <- session.store.cheat(session.player_id, target, action, args, now) do
      if target_id != session.player_id, do: session.notify.(target_id)
      state_reply(id, session, now)
    else
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("cheat", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid cheat."), session}

  defp handle(_type, _payload, id, session),
    do: {error(id, "bad_message", "Unknown message type."), session}

  defp cheat_target(%{"player" => name}) when is_binary(name) and name != "",
    do: {:ok, {:player, String.trim(name)}}

  defp cheat_target(%{"cityId" => city_id}) when is_binary(city_id), do: {:ok, {:city, city_id}}
  defp cheat_target(_payload), do: {:error, "bad_message"}

  @doc "Tells a player's open sockets that their game changed (Age3Web.GameSocket pushes them the new state)."
  def notify(player_id) do
    Registry.dispatch(Age3.Players, player_id, fn sockets ->
      for {pid, _} <- sockets, do: send(pid, :refresh)
    end)
  end

  @doc "The push for a change made by someone else (a cheat): the player's whole state, with no id. nil if unreadable."
  def refresh(session) do
    case state_reply(nil, session, session.now.()) do
      {%{type: "state"} = push, _session} -> push
      _ -> nil
    end
  end

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
  defp message("research_busy"), do: "This Academy is already researching something."
  defp message("no_academy"), do: "This city has no Academy."
  defp message("academy_busy"), do: "The Academy can't research and be upgraded at the same time."
  defp message("already_researching"), do: "That is already being researched in another city."
  defp message("requirement_not_met"), do: "Requirements not met."
  defp message("barracks_busy"), do: "A Barracks can't train and be upgraded at the same time."
  defp message("train_queue_full"), do: "This Barracks' queue is full. A higher level queues more."
  defp message("not_enough_population"), do: "Not enough idle population."
  defp message("bad_slot"), do: "That can't be built there."
  defp message("max_level"), do: "Already at the highest level."

  defp message("too_early"),
    do: "Speedup is only free in the last 5 minutes of a build, research or training."

  defp message("player_not_found"), do: "No player with that name."
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
