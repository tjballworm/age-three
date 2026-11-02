defmodule Age3.AccountsTest do
  # Logins against Postgres. Run with: mix test --include db
  use ExUnit.Case, async: true

  @moduletag :db

  alias Age3.Accounts

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
  end

  test "set_password creates an account that can log in" do
    assert {:ok, %{username: "Test Lord", password: "hunter2hunter2"}} =
             Accounts.set_password(" Test Lord ", "hunter2hunter2")

    assert {:ok, id} = Accounts.authenticate("Test Lord", "hunter2hunter2")
    assert :error = Accounts.authenticate("Test Lord", "wrong password")
    assert :error = Accounts.authenticate("Nobody Here", "hunter2hunter2")

    token = Accounts.new_token(id)
    assert {:ok, ^id} = Accounts.player_for_token(token)
    assert :error = Accounts.player_for_token(token <> "x")
  end

  test "a new password logs out old tokens" do
    {:ok, _} = Accounts.set_password("Test Lord", "first password")
    {:ok, id} = Accounts.authenticate("Test Lord", "first password")
    token = Accounts.new_token(id)

    {:ok, _} = Accounts.set_password("Test Lord", "second password")
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

  test "leaving out the password makes a random one" do
    assert {:ok, %{password: password}} = Accounts.set_password("Test Lord")
    assert String.length(password) == 12
    assert {:ok, _} = Accounts.authenticate("Test Lord", password)
  end

  test "list shows who can log in" do
    {:ok, _} = Age3.Store.Pg.find_or_create_player("No Password")
    {:ok, _} = Accounts.set_password("Has Password", "long enough password")
    accounts = Accounts.list()
    assert %{name: "No Password", canLogIn: false} in accounts
    assert %{name: "Has Password", canLogIn: true} in accounts
  end
end
