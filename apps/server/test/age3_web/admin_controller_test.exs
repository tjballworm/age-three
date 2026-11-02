defmodule Age3Web.AdminControllerTest do
  # The admin page's calls, through the real endpoint and router. Not async: it changes the admin key setting.
  use ExUnit.Case

  import Plug.Test
  import Plug.Conn

  @key String.duplicate("k", 40)

  setup do
    old = Application.get_env(:age3, :admin_key)
    Application.put_env(:age3, :admin_key, @key)
    on_exit(fn -> Application.put_env(:age3, :admin_key, old) end)
  end

  defp call(method, path, key, body \\ nil) do
    conn = conn(method, path, body && Jason.encode!(body))
    conn = if key, do: put_req_header(conn, "authorization", "Bearer " <> key), else: conn
    conn = if body, do: put_req_header(conn, "content-type", "application/json"), else: conn
    Age3Web.Endpoint.call(conn, [])
  end

  test "the page loads without a key" do
    conn = call(:get, "/admin", nil)
    assert conn.status == 200
    assert conn.resp_body =~ "Age Three admin"
  end

  test "the API refuses a missing or wrong key" do
    assert call(:get, "/admin/api/accounts", nil).status == 401
    assert call(:get, "/admin/api/accounts", "wrong").status == 401
    assert call(:post, "/admin/api/accounts", @key <> "x", %{name: "Someone"}).status == 401
  end

  test "the API is off when the key is unset or too short" do
    Application.put_env(:age3, :admin_key, nil)
    assert call(:get, "/admin/api/accounts", "").status == 401

    Application.put_env(:age3, :admin_key, "short")
    assert call(:get, "/admin/api/accounts", "short").status == 401
  end

  describe "with the database" do
    @describetag :db

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Age3.Repo, {:shared, self()})
    end

    test "creates an account and lists it" do
      conn = call(:post, "/admin/api/accounts", @key, %{name: "Admin Made", password: ""})
      assert conn.status == 200
      assert %{"username" => "Admin Made", "password" => password} = Jason.decode!(conn.resp_body)
      assert {:ok, _} = Age3.Accounts.authenticate("Admin Made", password)

      conn = call(:get, "/admin/api/accounts", @key)
      assert %{"name" => "Admin Made", "canLogIn" => true} in Jason.decode!(conn.resp_body)["accounts"]
    end

    test "explains a bad password" do
      conn = call(:post, "/admin/api/accounts", @key, %{name: "Admin Made", password: "short"})
      assert conn.status == 422
      assert Jason.decode!(conn.resp_body)["error"] =~ "at least 8"
    end
  end
end
