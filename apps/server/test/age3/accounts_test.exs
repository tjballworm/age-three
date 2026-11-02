defmodule Age3.AccountsTest do
  # Logins against Postgres. Run with: mix test --include db
  use ExUnit.Case, async: true

  @moduletag :db

  import ExUnit.CaptureIO
  alias Age3.Accounts

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
  end

  # set_password prints the username and password; keep that out of the test output
  defp set_password(name, password) do
    capture_io(fn -> send(self(), Accounts.set_password(name, password)) end)
  end

  test "set_password creates an account that can log in" do
    set_password("Test Lord", "hunter2hunter2")
    assert_received :ok

    assert {:ok, id} = Accounts.authenticate("Test Lord", "hunter2hunter2")
    assert :error = Accounts.authenticate("Test Lord", "wrong password")
    assert :error = Accounts.authenticate("Nobody Here", "hunter2hunter2")

    token = Accounts.new_token(id)
    assert {:ok, ^id} = Accounts.player_for_token(token)
    assert :error = Accounts.player_for_token(token <> "x")
  end

  test "a new password logs out old tokens" do
    set_password("Test Lord", "first password")
    {:ok, id} = Accounts.authenticate("Test Lord", "first password")
    token = Accounts.new_token(id)

    set_password("Test Lord", "second password")
    assert :error = Accounts.player_for_token(token)
    assert :error = Accounts.authenticate("Test Lord", "first password")
    assert {:ok, ^id} = Accounts.authenticate("Test Lord", "second password")
  end

  test "players without a password can't log in" do
    {:ok, _id} = Age3.Store.Pg.find_or_create_player("Old Dev Login")
    assert :error = Accounts.authenticate("Old Dev Login", "")
  end

  test "set_password checks its input" do
    assert {:error, _} = Accounts.set_password("x", "long enough password")
    assert {:error, _} = Accounts.set_password("Test Lord", "short")
  end

  test "generated passwords are printed" do
    output = capture_io(fn -> Accounts.set_password("Test Lord") end)
    assert output =~ ~r/username: Test Lord\npassword: \S{12}\n/
  end
end
