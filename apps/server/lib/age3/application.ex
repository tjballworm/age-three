defmodule Age3.Application do
  # The server's entry point (like cmd/server/main.go). Instead of starting goroutines by hand, it lists the
  # long-running parts and hands them to a supervisor, which starts them in order and restarts any that crash.
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:age3, :start_repo, true) do
        [
          # the database connection pool
          Age3.Repo,
          # applies any migrations not yet run, then steps aside; startup waits for it
          {Ecto.Migrator, repos: [Age3.Repo]}
        ]
      else
        []
      end ++
        [
          # HTTP: /health and the WebSocket at /ws
          Age3Web.Endpoint
        ]

    # one_for_one: if one child crashes, only that child is restarted
    Supervisor.start_link(children, strategy: :one_for_one, name: Age3.Supervisor)
  end
end
