defmodule Age3Web.AdminController do
  # The admin page at /admin, for making player accounts without a terminal.
  #
  # The page itself is public, but it does nothing without the admin key: every call to /admin/api needs the
  # header "Authorization: Bearer <key>", where the key is the ADMIN_KEY secret on Fly. With no ADMIN_KEY (or
  # one under 32 characters) every call is refused, so the admin page is off by default.
  use Phoenix.Controller, formats: []

  alias Age3.Accounts

  plug :require_admin_key when action in [:list, :set_password]

  # GET /admin
  def page(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, Age3Web.AdminPage.html())
  end

  # GET /admin/api/accounts: every player and whether they can log in
  def list(conn, _params), do: json(conn, %{accounts: Accounts.list()})

  # POST /admin/api/accounts {"name": ..., "password": optional}: create the account, or reset its password
  def set_password(conn, %{"name" => name} = params) when is_binary(name) do
    result =
      case params["password"] do
        password when is_binary(password) and password != "" -> Accounts.set_password(name, password)
        _ -> Accounts.set_password(name)
      end

    case result do
      {:ok, account} -> json(conn, account)
      {:error, message} -> conn |> put_status(422) |> json(%{error: message})
    end
  end

  def set_password(conn, _params), do: conn |> put_status(400) |> json(%{error: "name is required"})

  defp require_admin_key(conn, _opts) do
    key = Application.get_env(:age3, :admin_key)

    given =
      case get_req_header(conn, "authorization") do
        ["Bearer " <> given] -> given
        _ -> ""
      end

    # comparing hashes takes the same time whatever the key, so timing doesn't leak how much matched
    if is_binary(key) and byte_size(key) >= 32 and
         :crypto.hash_equals(:crypto.hash(:sha256, given), :crypto.hash(:sha256, key)) do
      conn
    else
      conn |> put_status(401) |> json(%{error: "wrong admin key"}) |> halt()
    end
  end
end
