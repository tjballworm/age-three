defmodule Age3Web.Router do
  # Which URL goes to which handler (like the http.ServeMux in main.go).
  use Phoenix.Router

  get "/health", Age3Web.HealthController, :show
  get "/ws", Age3Web.SocketController, :upgrade
end
