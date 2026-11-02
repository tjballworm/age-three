import Config

# Tests use a fake store and no database, like the Go tests did. Tests tagged :db use a real one.
config :age3, start_repo: false, start_server: false
config :age3, Age3.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warning

# password hashing is slow on purpose; tests don't need it to be
config :age3, pbkdf2_rounds: 1_000
