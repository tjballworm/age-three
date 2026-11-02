defmodule Age3Web.Router do
  # Which URL goes to which handler (like the http.ServeMux in main.go).
  use Phoenix.Router

  get "/health", Age3Web.HealthController, :show
  get "/ws", Age3Web.SocketController, :upgrade

  # The admin page, and the JSON calls it makes. Every call needs the admin key (see AdminController).
  pipeline :admin_api do
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  end

  get "/admin", Age3Web.AdminController, :page

  scope "/admin/api" do
    pipe_through :admin_api
    get "/accounts", Age3Web.AdminController, :list
    post "/accounts", Age3Web.AdminController, :set_password
  end
end
