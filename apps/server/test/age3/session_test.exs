defmodule Age3.SessionTest do
  # The Go session tests, ported. Each test feeds raw messages to a fresh session and checks the replies.
  use ExUnit.Case, async: true

  alias Age3.Session

  # Feeds each message to the session in turn and returns the replies, round-tripped through JSON like the
  # client sees them.
  defp run(messages) do
    # wake and notify tell the test process when the task runner or another player's sockets would be told
    test = self()

    session =
      Session.new(
        store: Age3.FakeStore,
        now: fn -> 1_000 end,
        wake: &send(test, {:wake, &1}),
        notify: &send(test, {:notify, &1})
      )

    {replies, _session} =
      Enum.map_reduce(messages, session, fn raw, session ->
        {reply, session} = Session.receive(session, raw)
        {reply |> Jason.encode!() |> Jason.decode!(), session}
      end)

    replies
  end

  defp login(password, version \\ Session.version()) do
    payload = %{version: version, username: "Lord TJ", password: password}
    Jason.encode!(%{type: "login", id: 1, payload: payload})
  end

  defp hello(payload) do
    Jason.encode!(%{type: "hello", id: 1, payload: Map.put(payload, :version, Session.version())})
  end

  @get_state ~s({"type":"getState","id":2,"payload":{}})

  test "rejects junk" do
    assert [%{"type" => "error"}, %{"type" => "error"}] =
             run(["not json", ~s({"type":"launchNukes","payload":{}})])
  end

  test "needs a login first" do
    assert [%{"type" => "error", "id" => 1, "payload" => %{"code" => "not_logged_in"}}] =
             run([~s({"type":"getState","id":1,"payload":{}})])
  end

  test "login hands out a token, then state works" do
    assert [welcome, state] = run([login("secret123"), @get_state])
    assert %{"type" => "welcome", "id" => 1, "payload" => %{"playerId" => "p1", "token" => "t1"}} = welcome
    assert %{"type" => "state", "id" => 2, "payload" => %{"player" => %{"name" => "Lord TJ"}}} = state
  end

  test "wrong password is refused and doesn't log in" do
    assert [refused, state] = run([login("guess"), @get_state])
    assert refused["payload"]["code"] == "bad_login"
    assert state["payload"]["code"] == "not_logged_in"
  end

  test "hello with a saved token logs back in, without a new token" do
    assert [%{"type" => "welcome", "payload" => welcome}, %{"type" => "state"}] =
             run([hello(%{token: "t1"}), @get_state])

    assert welcome["playerId"] == "p1"
    refute Map.has_key?(welcome, "token")
  end

  test "hello with an unknown token asks for a new login" do
    assert [refused, state] = run([hello(%{token: "stolen"}), @get_state])
    assert refused["payload"]["code"] == "session_expired"
    assert state["payload"]["code"] == "not_logged_in"
  end

  test "the old name-only hello no longer logs in" do
    assert [%{"payload" => %{"code" => "bad_message"}}] = run([hello(%{name: "Lord TJ"})])
  end

  test "state carries the tasks" do
    assert [_, %{"payload" => %{"tasks" => [], "serverTime" => 1_000}}] =
             run([login("secret123"), ~s({"type":"getState","id":2,"payload":{}})])
  end

  test "build replies with the new state and wakes the task runner" do
    assert [_, %{"type" => "state", "id" => 2}] =
             run([
               login("secret123"),
               ~s({"type":"build","id":2,"payload":{"cityId":"c1","slot":0,"type":"cottage"}})
             ])

    assert_received {:wake, 46_000}
  end

  test "build errors carry their code" do
    assert [_, %{"type" => "error", "payload" => %{"code" => "queue_busy"}}] =
             run([
               login("secret123"),
               ~s({"type":"build","id":2,"payload":{"cityId":"c1","slot":"f2"}})
             ])

    assert [_, %{"payload" => %{"code" => "bad_message"}}] =
             run([login("secret123"), ~s({"type":"build","id":2,"payload":{"slot":0}})])

    refute_received {:wake, _}
  end

  test "cancelBuild" do
    assert [_, %{"type" => "state"}, %{"payload" => %{"code" => "bad_message"}}] =
             run([
               login("secret123"),
               ~s({"type":"cancelBuild","id":2,"payload":{"cityId":"c1","taskId":"t1"}}),
               ~s({"type":"cancelBuild","id":3,"payload":{"cityId":"c1","taskId":"nope"}})
             ])
  end

  test "speedUp" do
    assert [_, %{"type" => "state"}, %{"payload" => %{"code" => "too_early", "message" => msg}}] =
             run([
               login("secret123"),
               ~s({"type":"speedUp","id":2,"payload":{"cityId":"c1","taskId":"t1"}}),
               ~s({"type":"speedUp","id":3,"payload":{"cityId":"c1","taskId":"t2"}})
             ])

    assert msg =~ "5 minutes"
  end

  test "research replies with the new state and wakes the task runner" do
    research = fn tech -> Jason.encode!(%{type: "research", id: 2, payload: %{cityId: "c1", tech: tech}}) end

    assert [_, %{"type" => "state", "id" => 2}, %{"type" => "error", "payload" => %{"code" => code}}, bad] =
             run([login("secret123"), research.("agriculture"), research.("archery"), research.(7)])

    assert code == "requirement_not_met"
    assert %{"type" => "error", "payload" => %{"code" => "bad_message"}} = bad
    assert_received {:wake, 401_000}
  end

  test "train replies with the new state and wakes the task runner" do
    train = fn troop, count ->
      Jason.encode!(%{type: "train", id: 2, payload: %{cityId: "c1", slot: 4, troop: troop, count: count}})
    end

    assert [_, %{"type" => "state", "id" => 2}, %{"type" => "error", "payload" => %{"code" => code}}, bad] =
             run([login("secret123"), train.("warrior", 10), train.("archer", 10), train.("warrior", "ten")])

    assert code == "requirement_not_met"
    assert %{"type" => "error", "payload" => %{"code" => "bad_message"}} = bad
    assert_received {:wake, 251_000}
  end

  test "hire, dismiss and setMayor reply with the new state" do
    msg = fn type, payload ->
      Jason.encode!(%{type: type, id: 2, payload: Map.put(payload, :cityId, "c1")})
    end

    assert [
             _,
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "offer_gone", "message" => gone}},
             %{"type" => "error", "payload" => %{"code" => "bad_message"}},
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "hero_busy"}},
             %{"type" => "state"},
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "bad_message"}}
           ] =
             run([
               login("secret123"),
               msg.("hire", %{offerId: "o1"}),
               msg.("hire", %{offerId: "o2"}),
               msg.("hire", %{offerId: 1}),
               msg.("dismiss", %{heroId: "h1"}),
               msg.("dismiss", %{heroId: "h2"}),
               msg.("setMayor", %{heroId: "h1"}),
               msg.("setMayor", %{heroId: nil}),
               msg.("setMayor", %{})
             ])

    assert gone =~ "left the Inn"
  end

  test "march and recall wake the task runner; reports come without and with the battle" do
    msg = fn type, payload -> Jason.encode!(%{type: type, id: 2, payload: payload}) end
    send = %{cityId: "c1", x: 10, y: 20, heroId: "h1", troops: %{warrior: 100}}

    assert [
             _,
             %{"type" => "state"},
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "bad_target", "message" => target}},
             %{"type" => "error", "payload" => %{"code" => "bad_message"}},
             %{"type" => "state"},
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "already_returning"}},
             %{"type" => "reports", "payload" => %{"reports" => [%{"id" => "r1"}]}},
             %{"type" => "report", "payload" => %{"report" => %{"result" => %{"winner" => "attacker"}}}},
             %{"type" => "error", "payload" => %{"code" => "bad_message"}},
             %{"type" => "state"}
           ] =
             run([
               login("secret123"),
               msg.("march", send),
               msg.("march", Map.put(send, :camp, 30)),
               msg.("march", %{send | x: 11}),
               msg.("march", Map.put(send, :heroId, 5)),
               msg.("march", %{cityId: "c1", x: 10, y: 20, mission: "scout", troops: %{scout: 10}}),
               msg.("recall", %{cityId: "c1", taskId: "m1"}),
               msg.("recall", %{cityId: "c1", taskId: "m2"}),
               msg.("getReports", %{}),
               msg.("getReport", %{reportId: "r1"}),
               msg.("getReport", %{reportId: "r2"}),
               msg.("readAllReports", %{})
             ])

    assert target =~ "NPC"
    assert_received {:wake, 61_000}
    # the camp wave delays the attack
    assert_received {:wake, 91_000}
    assert_received {:wake, 31_000}
  end

  test "refreshInn replies with the new state" do
    msg = fn payload -> Jason.encode!(%{type: "refreshInn", id: 2, payload: payload}) end

    assert [
             _,
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "no_inn"}},
             %{"type" => "error", "payload" => %{"code" => "bad_message"}}
           ] = run([login("secret123"), msg.(%{cityId: "c1"}), msg.(%{cityId: "c2"}), msg.(%{})])
  end

  test "cancelTrain wakes the task runner, as the next batch may end sooner" do
    cancel = fn task ->
      Jason.encode!(%{type: "cancelTrain", id: 2, payload: %{cityId: "c1", taskId: task}})
    end

    assert [_, %{"type" => "state"}, %{"type" => "error", "payload" => %{"code" => "bad_message"}}] =
             run([login("secret123"), cancel.("t1"), cancel.("t9")])

    assert_received {:wake, 1_000}
  end

  test "buildFort, cancelFort and assignPoints" do
    msg = fn type, payload ->
      Jason.encode!(%{type: type, id: 2, payload: Map.put(payload, :cityId, "c1")})
    end

    assert [
             _,
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "no_wall_space"}},
             %{"type" => "error", "payload" => %{"code" => "bad_message"}},
             %{"type" => "state"},
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "not_enough_points"}}
           ] =
             run([
               login("secret123"),
               msg.("buildFort", %{fort: "trap", count: 10}),
               msg.("buildFort", %{fort: "trap", count: 99_999_999}),
               msg.("buildFort", %{fort: "trap", count: "10"}),
               msg.("cancelFort", %{taskId: "t1"}),
               msg.("assignPoints", %{heroId: "h1", politics: 1}),
               msg.("assignPoints", %{heroId: "h1", attack: 9})
             ])

    assert_received {:wake, 61_000}
  end

  test "rewardHero, renameHero and resetPoints" do
    msg = fn type, payload ->
      Jason.encode!(%{type: type, id: 2, payload: Map.merge(%{cityId: "c1", heroId: "h1"}, payload)})
    end

    assert [
             _,
             %{"type" => "state"},
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "bad_message"}},
             %{"type" => "error", "payload" => %{"code" => "reward_cooldown"}},
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "bad_hero_name"}},
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "nothing_to_reset"}}
           ] =
             run([
               login("secret123"),
               msg.("rewardHero", %{kind: "gold"}),
               msg.("rewardHero", %{kind: "medal", medal: "cross"}),
               msg.("rewardHero", %{kind: "medal"}),
               msg.("rewardHero", %{heroId: "h2", kind: "gold"}),
               msg.("renameHero", %{name: "  Sir   Bob "}),
               msg.("renameHero", %{name: "<script>"}),
               msg.("resetPoints", %{}),
               msg.("resetPoints", %{heroId: "h2"})
             ])
  end

  test "chat and mail" do
    msg = fn type, payload -> Jason.encode!(%{type: type, id: 2, payload: payload}) end

    assert [
             _,
             %{"type" => "chat", "payload" => %{"text" => "hi"}},
             %{"type" => "error", "payload" => %{"code" => "no_alliance"}},
             %{"type" => "chatHistory", "payload" => %{"messages" => []}},
             %{"type" => "mail", "payload" => %{"inbox" => []}},
             %{"type" => "error", "payload" => %{"code" => "player_not_found"}},
             %{"type" => "mail"},
             %{"type" => "error", "payload" => %{"code" => "bad_message"}}
           ] =
             run([
               login("secret123"),
               msg.("chat", %{channel: "world", text: "hi"}),
               msg.("chat", %{channel: "alliance", text: "hi"}),
               msg.("getChat", %{}),
               msg.("sendMail", %{to: "Other", subject: "Hello", body: "Hi there"}),
               msg.("sendMail", %{to: "Nobody", subject: "Hello", body: "Hi there"}),
               msg.("readMail", %{mailId: "m1"}),
               msg.("readMail", %{mailId: "m2"})
             ])
  end

  test "the marketplace" do
    msg = fn type, payload ->
      Jason.encode!(%{type: type, id: 2, payload: Map.put(payload, :cityId, "c1")})
    end

    assert [
             _,
             %{"type" => "market", "payload" => %{"level" => 1}},
             %{"type" => "state"},
             %{"type" => "error", "payload" => %{"code" => "market_full"}},
             %{"type" => "state"}
           ] =
             run([
               login("secret123"),
               msg.("getMarket", %{}),
               msg.("marketOrder", %{side: "sell", resource: "food", amount: 100, price: 50}),
               msg.("marketOrder", %{side: "buy", resource: "food", amount: 100, price: 50}),
               msg.("cancelOrder", %{orderId: "o1"})
             ])
  end

  test "cancelResearch" do
    cancel = fn task ->
      Jason.encode!(%{type: "cancelResearch", id: 2, payload: %{cityId: "c1", taskId: task}})
    end

    assert [_, %{"type" => "state"}, %{"type" => "error", "payload" => %{"code" => "bad_message"}}] =
             run([login("secret123"), cancel.("t1"), cancel.("t9")])
  end

  test "setTax takes a whole number from 0 to 100" do
    assert [
             _,
             %{"type" => "state"},
             %{"payload" => %{"code" => "bad_message"}},
             %{"payload" => %{"code" => "bad_message"}}
           ] =
             run([
               login("secret123"),
               ~s({"type":"setTax","id":2,"payload":{"cityId":"c1","taxRate":25}}),
               ~s({"type":"setTax","id":3,"payload":{"cityId":"c1","taxRate":101}}),
               ~s({"type":"setTax","id":4,"payload":{"cityId":"c1","taxRate":12.5}})
             ])
  end

  test "comfort takes Disaster Relief or Praying" do
    assert [
             _,
             %{"type" => "state"},
             %{"payload" => %{"code" => "comfort_cooldown"}},
             %{"payload" => %{"code" => "bad_message"}}
           ] =
             run([
               login("secret123"),
               ~s({"type":"comfort","id":2,"payload":{"cityId":"c1","kind":"pray"}}),
               ~s({"type":"comfort","id":3,"payload":{"cityId":"c2","kind":"relief"}}),
               ~s({"type":"comfort","id":4,"payload":{"cityId":"c1","kind":"feast"}})
             ])
  end

  test "levy, renameCity, demolish and abandonCity" do
    assert [
             _,
             %{"type" => "state"},
             %{"payload" => %{"code" => "levy_cooldown"}},
             %{"payload" => %{"code" => "bad_message"}},
             %{"type" => "state"},
             %{"payload" => %{"code" => "bad_city_name"}},
             %{"payload" => %{"code" => "bad_city_name"}},
             %{"type" => "state"},
             %{"payload" => %{"code" => "cant_demolish"}},
             %{"type" => "state"},
             %{"payload" => %{"code" => "troops_out"}},
             %{"payload" => %{"code" => "bad_message"}}
           ] =
             run([
               login("secret123"),
               ~s({"type":"levy","id":2,"payload":{"cityId":"c1","resource":"gold"}}),
               ~s({"type":"levy","id":3,"payload":{"cityId":"c2","resource":"food"}}),
               ~s({"type":"levy","id":4,"payload":{"cityId":"c1","resource":"gems"}}),
               ~s({"type":"renameCity","id":5,"payload":{"cityId":"c1","name":"  New   Camelot "}}),
               ~s({"type":"renameCity","id":6,"payload":{"cityId":"c1","name":"   "}}),
               ~s({"type":"renameCity","id":7,"payload":{"cityId":"c1","name":"A name that is far too long"}}),
               ~s({"type":"demolish","id":8,"payload":{"cityId":"c1","slot":3}}),
               ~s({"type":"demolish","id":9,"payload":{"cityId":"c1","slot":"townhall"}}),
               ~s({"type":"abandonCity","id":10,"payload":{"cityId":"c2","moveHeroesTo":"c1"}}),
               ~s({"type":"abandonCity","id":11,"payload":{"cityId":"c1","moveHeroesTo":"c2"}}),
               ~s({"type":"abandonCity","id":12,"payload":{"cityId":"c1"}})
             ])
  end

  test "comfort also takes Blessing and Population Raising" do
    assert [_, %{"type" => "state"}, %{"type" => "state"}] =
             run([
               login("secret123"),
               ~s({"type":"comfort","id":2,"payload":{"cityId":"c1","kind":"bless"}}),
               ~s({"type":"comfort","id":3,"payload":{"cityId":"c1","kind":"raise"}})
             ])
  end

  test "setGate, setDefender and persuade; state lists other lords' cities" do
    assert [
             %{"type" => "welcome"},
             %{"type" => "state", "payload" => %{"lords" => [%{"owner" => "Other"}]}},
             %{"type" => "state"},
             %{"payload" => %{"code" => "bad_message"}},
             %{"type" => "state"},
             %{"payload" => %{"code" => "not_enough_resources"}}
           ] =
             run([
               login("secret123"),
               ~s({"type":"setGate","id":2,"payload":{"cityId":"c1","open":true}}),
               ~s({"type":"setDefender","id":3,"payload":{"cityId":"c1","heroId":null}}),
               ~s({"type":"setDefender","id":4,"payload":{"cityId":"c1","heroId":7}}),
               ~s({"type":"persuade","id":5,"payload":{"cityId":"c1","heroId":"h1"}}),
               ~s({"type":"persuade","id":6,"payload":{"cityId":"c1","heroId":"h2"}})
             ])
  end

  test "heal heals wounded for gold, or says there aren't that many" do
    assert [
             _,
             %{"type" => "state"},
             %{
               "payload" => %{"code" => "not_enough_wounded", "message" => "There aren't that many wounded."}
             },
             %{"payload" => %{"code" => "bad_message"}}
           ] =
             run([
               login("secret123"),
               ~s({"type":"heal","id":2,"payload":{"cityId":"c1","troops":{"warrior":10}}}),
               ~s({"type":"heal","id":3,"payload":{"cityId":"c1","troops":{"archer":10}}}),
               ~s({"type":"heal","id":4,"payload":{"cityId":"c1"}})
             ])
  end

  test "promote goes up the rank or title ladder" do
    assert [
             _,
             %{"type" => "state"},
             %{"payload" => %{"code" => "not_enough_medals", "message" => "Not enough medals."}},
             %{"payload" => %{"code" => "bad_message"}}
           ] =
             run([
               login("secret123"),
               ~s({"type":"promote","id":2,"payload":{"cityId":"c1","ladder":"title"}}),
               ~s({"type":"promote","id":3,"payload":{"cityId":"c2","ladder":"rank"}}),
               ~s({"type":"promote","id":4,"payload":{"cityId":"c1","ladder":"emperor"}})
             ])
  end

  test "cheats work on your own city or any player by name, with no permission check" do
    cheat = fn payload -> Jason.encode!(%{type: "cheat", id: 2, payload: payload}) end

    assert [
             _,
             %{"type" => "state"},
             %{"type" => "state"},
             %{"payload" => %{"code" => "player_not_found"}},
             %{"payload" => %{"code" => "bad_message"}},
             %{"payload" => %{"code" => "bad_message"}},
             %{"payload" => %{"code" => "bad_message"}}
           ] =
             run([
               login("secret123"),
               cheat.(%{action: "addResources", cityId: "c1", amounts: %{gold: 1_000_000}}),
               cheat.(%{action: "addTroops", player: "Other", troops: %{warrior: 500}}),
               cheat.(%{action: "finishAll", player: "Nobody"}),
               # unknown resource, unknown action, and no city or player
               cheat.(%{action: "addResources", cityId: "c1", amounts: %{diamonds: 5}}),
               cheat.(%{action: "launchNukes", cityId: "c1"}),
               cheat.(%{action: "fillResources"})
             ])

    # only the other player's game is pushed a new state
    assert_received {:notify, "p2"}
    refute_received {:notify, "p1"}
  end

  test "refresh pushes the whole state with no id" do
    session = Session.new(store: Age3.FakeStore, player_id: "p1", now: fn -> 7 end)
    assert %{type: "state", payload: %{serverTime: 7, reason: "cheat"}} = push = Session.refresh(session)
    refute Map.has_key?(push, :id)
    assert %{payload: %{reason: "attacked"}} = Session.refresh(session, "attacked")
  end

  test "commands need a login first" do
    assert [%{"payload" => %{"code" => "not_logged_in"}}] =
             run([~s({"type":"build","id":1,"payload":{"cityId":"c1","slot":0}})])
  end

  test "task_done pushes the task with the new state" do
    session = Session.new(store: Age3.FakeStore, player_id: "p1", now: fn -> 7 end)

    assert %{type: "taskDone", payload: %{task: %{id: "t1"}, tasks: [], serverTime: 7}} =
             Session.task_done(session, %{id: "t1"})
  end

  test "task_done includes the other players' cities so the map keeps them" do
    session = Session.new(store: Age3.FakeStore, player_id: "p1", now: fn -> 7 end)
    assert %{payload: %{lords: [%{id: "c9"}]}} = Session.task_done(session, %{id: "t1"})
  end

  test "version mismatch" do
    assert [%{"payload" => %{"code" => "version_mismatch"}}] =
             run([login("secret123", Session.version() + 1)])
  end

  test "ping" do
    assert [%{"type" => "pong", "id" => 3, "payload" => %{"at" => 5}}] =
             run([~s({"type":"ping","id":3,"payload":{"at":5}})])
  end

  test "replies without an id when the request had none" do
    assert [reply] = run([~s({"type":"ping","payload":{"at":5}})])
    refute Map.has_key?(reply, "id")
  end
end
