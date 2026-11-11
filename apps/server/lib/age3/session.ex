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
              "comfort",
              "setGate",
              "setDefender",
              "persuade",
              "research",
              "cancelResearch",
              "train",
              "cancelTrain",
              "buildFort",
              "cancelFort",
              "hire",
              "dismiss",
              "setMayor",
              "assignPoints",
              "march",
              "recall",
              "setGarrison",
              "abandonValley",
              "imposePolicy",
              "promote",
              "getReports",
              "getReport",
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

  # Build wall fortifications: {cityId, fort, count}, fort being trap, abatis, tower, log or trebuchet. The
  # batch joins the end of the walls' queue.
  defp handle("buildFort", %{"cityId" => city_id, "fort" => fort, "count" => count}, id, session)
       when is_binary(city_id) and is_binary(fort) and is_integer(count),
       do: command(id, session, &session.store.build_forts(session.player_id, city_id, fort, count, &1))

  defp handle("buildFort", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid fortification order."), session}

  # Stop a fortification batch and get its cost back: {cityId, taskId}.
  defp handle("cancelFort", %{"cityId" => city_id, "taskId" => task_id}, id, session)
       when is_binary(city_id) and is_binary(task_id),
       do: command(id, session, &session.store.cancel_forts(session.player_id, city_id, task_id, &1))

  defp handle("cancelFort", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid cancel."), session}

  defp handle("cancelTrain", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid cancel."), session}

  # Hire a hero from the city's Inn into its Feasting Hall: {cityId, offerId}, offerId being the id of one of the
  # Inn's offers (city.inn.offers). The fee is paid now. Replies with the new state.
  defp handle("hire", %{"cityId" => city_id, "offerId" => offer_id}, id, session)
       when is_binary(city_id) and is_binary(offer_id) do
    now = session.now.()

    case session.store.hire(session.player_id, city_id, offer_id, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("hire", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid hire."), session}

  # The Inn's free refresh: {cityId}. New offers now; the timed refresh stays where it was. Replies with state.
  defp handle("refreshInn", %{"cityId" => city_id}, id, session) when is_binary(city_id) do
    now = session.now.()

    case session.store.reroll_inn(session.player_id, city_id, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("refreshInn", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid refresh."), session}

  # Send a hero away for good: {cityId, heroId}. Only an idle hero (not the mayor, not marching).
  defp handle("dismiss", %{"cityId" => city_id, "heroId" => hero_id}, id, session)
       when is_binary(city_id) and is_binary(hero_id) do
    now = session.now.()

    case session.store.dismiss(session.player_id, city_id, hero_id, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("dismiss", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid dismiss."), session}

  # Appoint the city's mayor: {cityId, heroId}, or heroId null to have none. The old mayor goes back to idle.
  defp handle("setMayor", %{"cityId" => city_id, "heroId" => hero_id}, id, session)
       when is_binary(city_id) and (is_binary(hero_id) or is_nil(hero_id)) do
    now = session.now.()

    case session.store.set_mayor(session.player_id, city_id, hero_id, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("setMayor", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid mayor appointment."), session}

  # Send a march from a city to x, y: {cityId, x, y, heroId, troops: {warrior: 100, ...}, mission, camp, cargo}.
  # mission is "attack" (the default; needs a hero), "scout" (needs scouts, hero optional), "transport" (cargo:
  # resources to deliver), "reinforce" or "found" (250 workers and 10,000 of each resource build a city on a
  # flat). The troops, hero, cargo and the trip's food leave now; the mission happens when the march arrives
  # (after camping `camp` seconds for an attack), and a report follows. Replies with the new state.
  defp handle(
         "march",
         %{"cityId" => city_id, "x" => x, "y" => y, "troops" => %{} = troops} = payload,
         id,
         session
       )
       when is_binary(city_id) and is_integer(x) and is_integer(y) do
    now = session.now.()
    hero_id = payload["heroId"]

    opts = %{
      "camp" => Map.get(payload, "camp", 0),
      "mission" => Map.get(payload, "mission", "attack"),
      "cargo" => Map.get(payload, "cargo")
    }

    with true <- is_binary(hero_id) or is_nil(hero_id),
         {:ok, ends_at} <- session.store.march(session.player_id, city_id, x, y, hero_id, troops, now, opts) do
      session.wake.(ends_at)
      state_reply(id, session, now)
    else
      false -> {error(id, "bad_message", "Not a valid march."), session}
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("march", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid march."), session}

  # Turn a march around before it arrives: {cityId, taskId}. It takes as long to come back as it has been out.
  defp handle("recall", %{"cityId" => city_id, "taskId" => task_id}, id, session)
       when is_binary(city_id) and is_binary(task_id) do
    now = session.now.()

    case session.store.recall(session.player_id, city_id, task_id, now) do
      {:ok, ends_at} ->
        session.wake.(ends_at)
        state_reply(id, session, now)

      {:error, code} ->
        {error(id, code, message(code)), session}
    end
  end

  defp handle("recall", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid recall."), session}

  # A held historic city imposes a policy on another lord's city: {cityId, x, y, policy}. Replies with the state.
  defp handle("imposePolicy", %{"cityId" => city_id, "x" => x, "y" => y, "policy" => policy}, id, session)
       when is_binary(city_id) and is_integer(x) and is_integer(y) and is_binary(policy) do
    now = session.now.()

    case session.store.impose_policy(session.player_id, city_id, x, y, policy, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("imposePolicy", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid policy."), session}

  # The latest battle reports, without the battles: replies "reports" {reports: [...]}.
  defp handle("getReports", _payload, id, session),
    do: {reply(id, "reports", %{reports: session.store.reports(session.player_id)}), session}

  # One report with its whole battle: {reportId}. Marks it read. Replies "report" {report}.
  defp handle("getReport", %{"reportId" => report_id}, id, session) when is_binary(report_id) do
    case session.store.report(session.player_id, report_id) do
      {:ok, report} -> {reply(id, "report", %{report: report}), session}
      {:error, code} -> {error(id, code, "That report doesn't exist."), session}
    end
  end

  defp handle("getReport", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid report request."), session}

  # Finish a building's construction or upgrade for free when it has 5 minutes or less left: {cityId, taskId}.
  # Research, training and walls can't be sped up.
  defp handle("speedUp", %{"cityId" => city_id, "taskId" => task_id}, id, session)
       when is_binary(city_id) and is_binary(task_id) do
    now = session.now.()

    case session.store.speed_up(session.player_id, city_id, task_id, now) do
      :ok ->
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

  # Comfort a city's people: {cityId, kind: "relief" | "pray"} (Age3.Loyalty).
  defp handle("comfort", %{"cityId" => city_id, "kind" => kind}, id, session)
       when is_binary(city_id) and kind in ["relief", "pray"] do
    now = session.now.()

    case session.store.comfort(session.player_id, city_id, kind, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("comfort", _payload, id, session),
    do: {error(id, "bad_message", "Comfort with Disaster Relief or Praying."), session}

  # The Rally Spot's gate: {cityId, open}. Closed, the troops stay out of battles.
  defp handle("setGate", %{"cityId" => city_id, "open" => open}, id, session)
       when is_binary(city_id) and is_boolean(open) do
    now = session.now.()

    case session.store.set_gate(session.player_id, city_id, open, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("setGate", _payload, id, session),
    do: {error(id, "bad_message", "Open or close the gate with true or false."), session}

  # The Embassy's "let allies garrison this city" box: {cityId, allow}.
  defp handle("setGarrison", %{"cityId" => city_id, "allow" => allow}, id, session)
       when is_binary(city_id) and is_boolean(allow),
       do: command(id, session, &session.store.set_garrison(session.player_id, city_id, allow, &1))

  defp handle("setGarrison", _payload, id, session),
    do: {error(id, "bad_message", "Tick or untick with true or false."), session}

  # Give up a valley a city holds: {cityId, x, y}.
  defp handle("abandonValley", %{"cityId" => city_id, "x" => x, "y" => y}, id, session)
       when is_binary(city_id) and is_integer(x) and is_integer(y),
       do: command(id, session, &session.store.abandon_valley(session.player_id, city_id, x, y, &1))

  defp handle("abandonValley", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid valley."), session}

  # Spend a hero's stat points: {cityId, heroId, politics?, attack?, intelligence?}, each a number to add.
  defp handle("assignPoints", %{"cityId" => city_id, "heroId" => hero_id} = p, id, session)
       when is_binary(city_id) and is_binary(hero_id) do
    add = Map.take(p, ~w(politics attack intelligence))
    command(id, session, &session.store.assign_points(session.player_id, city_id, hero_id, add, &1))
  end

  defp handle("assignPoints", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid point assignment."), session}

  # The hero who leads a city's defence: {cityId, heroId} (null for nobody).
  defp handle("setDefender", %{"cityId" => city_id} = payload, id, session) when is_binary(city_id) do
    hero_id = payload["heroId"]
    now = session.now.()

    with true <- is_nil(hero_id) or is_binary(hero_id),
         :ok <- session.store.set_defender(session.player_id, city_id, hero_id, now) do
      state_reply(id, session, now)
    else
      false -> {error(id, "bad_message", "Not a valid hero."), session}
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("setDefender", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid hero."), session}

  # Persuade a captive hero to join: {cityId, heroId}. Release one with dismiss.
  defp handle("persuade", %{"cityId" => city_id, "heroId" => hero_id}, id, session)
       when is_binary(city_id) and is_binary(hero_id) do
    now = session.now.()

    case session.store.persuade(session.player_id, city_id, hero_id, now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("persuade", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid hero."), session}

  # One step up the rank or title ladder: {cityId, ladder: "rank" | "title"}. The gold comes from that city.
  defp handle("promote", %{"cityId" => city_id, "ladder" => ladder}, id, session)
       when is_binary(city_id) and ladder in ["rank", "title"] do
    now = session.now.()

    case session.store.promote(session.player_id, city_id, if(ladder == "rank", do: :rank, else: :title), now) do
      :ok -> state_reply(id, session, now)
      {:error, code} -> {error(id, code, message(code)), session}
    end
  end

  defp handle("promote", _payload, id, session),
    do: {error(id, "bad_message", "Not a valid promotion."), session}

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

  @doc """
  Tells a player's open sockets that their game changed (Age3Web.GameSocket pushes them the new state). reason is
  "cheat" (someone cheated on this account), "attacked" (an attack on one of their cities arrived) or "march" (their
  march reached another player's city while they weren't the one looking).
  """
  def notify(player_id, reason \\ "cheat") do
    Registry.dispatch(Age3.Players, player_id, fn sockets ->
      for {pid, _} <- sockets, do: send(pid, {:refresh, reason})
    end)
  end

  @doc "The push for a change made by someone else: the player's whole state and the reason, with no id. nil if unreadable."
  def refresh(session, reason \\ "cheat") do
    case state_reply(nil, session, session.now.()) do
      {%{type: "state", payload: payload} = push, _session} ->
        %{push | payload: Map.put(payload, :reason, reason)}

      _ ->
        nil
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
          payload: %{
            task: task,
            player: player,
            cities: cities,
            tasks: tasks,
            lords: session.store.lords(session.player_id),
            serverTime: now
          }
        }

      {:error, _} ->
        nil
    end
  end

  # A command that changes the game: run it at now and reply with the new state, or the error.
  defp command(id, session, fun) do
    now = session.now.()

    case fun.(now) do
      :ok ->
        # a cancel can bring the next queued task forward
        session.wake.(now)
        state_reply(id, session, now)

      {:ok, ends_at} when is_integer(ends_at) ->
        session.wake.(ends_at)
        state_reply(id, session, now)

      {:ok, _} ->
        state_reply(id, session, now)

      {:error, code} ->
        {error(id, code, message(code)), session}
    end
  end

  # One clock reading: resources are settled to exactly the serverTime the client projects from.
  defp state_reply(id, session, now) do
    case session.store.state(session.player_id, now) do
      {:ok, player, cities, tasks} ->
        payload = %{
          player: player,
          cities: cities,
          tasks: tasks,
          lords: session.store.lords(session.player_id),
          serverTime: now
        }

        {reply(id, "state", payload), session}

      {:error, :not_found} ->
        {error(id, "not_logged_in", "Player not found."), session}
    end
  end

  defp slot_key(slot) when is_integer(slot), do: Integer.to_string(slot)
  defp slot_key(slot) when is_binary(slot), do: slot
  defp slot_key(_slot), do: nil

  defp message("not_enough_resources"), do: "Not enough resources."
  defp message("not_enough_points"), do: "The hero doesn't have that many points."
  defp message("no_wall_space"), do: "Not enough fortified space on the walls."
  defp message("fort_queue_full"), do: "The walls' queue is full."
  defp message("comfort_cooldown"), do: "The people were comforted less than 15 minutes ago."
  defp message("own_city"), do: "That city is already yours."
  defp message("queue_busy"), do: "Something is already being built in this city."
  defp message("research_busy"), do: "This Academy is already researching something."
  defp message("no_academy"), do: "This city has no Academy."
  defp message("academy_busy"), do: "The Academy can't research and be upgraded at the same time."
  defp message("already_researching"), do: "That is already being researched in another city."
  defp message("requirement_not_met"), do: "Requirements not met."
  defp message("train_queue_full"), do: "This Barracks' queue is full. A higher level queues more."
  defp message("not_enough_population"), do: "Not enough idle population."
  defp message("bad_slot"), do: "That can't be built there."
  defp message("max_level"), do: "Already at the highest level."

  defp message("too_early"),
    do: "Speedup is only free in the last 5 minutes of a building's construction or upgrade."

  defp message("no_free_speedup"),
    do: "Only buildings can be sped up for free. Research, training and walls can't."

  defp message("player_not_found"), do: "No player with that name."
  defp message("no_inn"), do: "This city has no Inn."
  defp message("no_hall"), do: "Build a Feasting Hall to house heroes."
  defp message("hall_full"), do: "The Feasting Hall is full. Upgrade it or dismiss a hero."
  defp message("offer_gone"), do: "That hero has left the Inn. Here are the new ones."
  defp message("hero_busy"), do: "That hero is busy."
  defp message("no_rally_spot"), do: "Build a Rally Spot to send troops out."
  defp message("too_many_troops"), do: "Too many troops. Each Rally Spot level sends 10,000."

  defp message("too_many_marches"),
    do: "All this city's marches are out. Each Rally Spot level sends one march at a time."

  defp message("not_enough_troops"), do: "Not enough troops in the city."
  defp message("no_scouts"), do: "A scouting march needs at least one scout."
  defp message("not_enough_workers"), do: "Founding a city takes 250 workers."
  defp message("too_much_cargo"), do: "The troops can't carry that much. Send more, or transporters."
  defp message("own_valley"), do: "You already hold that valley."

  defp message("valley_cap"),
    do: "This city holds as many valleys as its Town Hall level. Upgrade it or abandon one."

  defp message("city_cap"), do: "Your title doesn't allow another city yet."
  defp message("not_allied"), do: "You can only reinforce an ally whose Embassy takes garrisons and has room."
  defp message("no_troops"), do: "Choose some troops to send."
  defp message("no_hero"), do: "Choose a hero to lead the march."
  defp message("hero_not_found"), do: "That hero isn't in those cities any more."
  defp message("bad_target"), do: "Only NPC, historic and player cities can be attacked."
  defp message("not_historic"), do: "Only a historic city you hold can impose policies."
  defp message("title_too_low"), do: "You need to be an Earl or above to impose policies."
  defp message("out_of_range"), do: "That city is outside this historic city's draft area."

  defp message("no_policies_left"),
    do: "This historic city has no policies left today. They come back at 00:00 UTC."

  defp message("already_returning"), do: "That march is already on its way back."
  defp message("not_enough_medals"), do: "Not enough medals."
  defp message("rank_too_low"), do: "Your rank is too low for that title."
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
