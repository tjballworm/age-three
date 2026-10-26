import Config

# Tests use a fake store and no database, like the Go tests did. Tests tagged :db use a real one.
config :age3, start_repo: false, start_server: false
config :age3, Age3.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warning
