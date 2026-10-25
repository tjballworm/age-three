defmodule Age3Web.Endpoint do
  # The HTTP entry point: every request passes through these plugs (steps) in order, then the router.
  use Phoenix.Endpoint, otp_app: :age3

  plug Plug.RequestId
  plug Age3Web.Router
end
