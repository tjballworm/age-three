defmodule Age3.SessionTest do
  # The Go session tests, ported. Each test feeds raw messages to a fresh session and checks the replies.
  use ExUnit.Case, async: true

  alias Age3.Session

  # Feeds each message to the session in turn and returns the replies, round-tripped through JSON like the
  # client sees them.
  defp run(messages) do
    # wake tells the test process when the task runner would be woken
    test = self()
    session = Session.new(store: Age3.FakeStore, now: fn -> 1_000 end, wake: &send(test, {:wake, &1}))

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

  test "commands need a login first" do
    assert [%{"payload" => %{"code" => "not_logged_in"}}] =
             run([~s({"type":"build","id":1,"payload":{"cityId":"c1","slot":0}})])
  end

  test "task_done pushes the task with the new state" do
    session = Session.new(store: Age3.FakeStore, player_id: "p1", now: fn -> 7 end)

    assert %{type: "taskDone", payload: %{task: %{id: "t1"}, tasks: [], serverTime: 7}} =
             Session.task_done(session, %{id: "t1"})
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
