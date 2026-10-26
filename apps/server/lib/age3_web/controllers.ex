defmodule Age3Web.HealthController do
  # GET /health answers "ok" for Fly's health checks.
  use Phoenix.Controller, formats: []

  def show(conn, _params), do: text(conn, "ok")
end

defmodule Age3Web.SocketController do
  # GET /ws turns the request into a WebSocket handled by Age3Web.GameSocket.
  use Phoenix.Controller, formats: []

  # Drop connections that send nothing (not even a pong) for this long. GameSocket pings every 30 s.
  @idle_timeout 75_000
  @max_message 64 * 1024

  def upgrade(conn, _params) do
    # Browsers on other origins (the Netlify sites, localhost:5173) connect here, so origins aren't checked
    # yet. Tighten this once real logins exist.
    conn
    |> WebSockAdapter.upgrade(Age3Web.GameSocket, [], timeout: @idle_timeout, max_frame_size: @max_message)
    |> halt()
  end
end

defmodule Age3Web.ErrorJSON do
  # The body for HTTP errors such as an unknown path: {"error": "Not Found"}.
  @moduledoc false
  def render(template, _assigns), do: %{error: Phoenix.Controller.status_message_from_template(template)}
end
