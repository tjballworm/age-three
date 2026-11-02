defmodule Age3.SessionTest do
  # The Go session tests, ported. Each test feeds raw messages to a fresh session and checks the replies.
  use ExUnit.Case, async: true

  alias Age3.Session

  # Feeds each message to the session in turn and returns the replies, round-tripped through JSON like the
  # client sees them.
  defp run(messages) do
    {replies, _session} =
      Enum.map_reduce(messages, Session.new(store: Age3.FakeStore), fn raw, session ->
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
