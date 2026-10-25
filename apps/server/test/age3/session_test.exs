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

  defp hello(version), do: ~s({"type":"hello","id":1,"payload":{"version":#{version},"name":"Lord TJ"}})

  test "rejects junk" do
    assert [%{"type" => "error"}, %{"type" => "error"}] =
             run(["not json", ~s({"type":"launchNukes","payload":{}})])
  end

  test "needs hello first" do
    assert [%{"type" => "error", "id" => 1, "payload" => %{"code" => "not_logged_in"}}] =
             run([~s({"type":"getState","id":1,"payload":{}})])
  end

  test "login and state" do
    assert [welcome, state] = run([hello(Session.version()), ~s({"type":"getState","id":2,"payload":{}})])
    assert %{"type" => "welcome", "id" => 1, "payload" => %{"playerId" => "p1"}} = welcome
    assert %{"type" => "state", "id" => 2, "payload" => %{"player" => %{"name" => "Lord TJ"}}} = state
  end

  test "version mismatch" do
    assert [%{"payload" => %{"code" => "version_mismatch"}}] = run([hello(Session.version() + 1)])
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
