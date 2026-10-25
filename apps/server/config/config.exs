# Settings fixed at build time. Secrets and anything read from the environment go in runtime.exs.
import Config

config :age3, ecto_repos: [Age3.Repo]

config :age3, Age3.Repo,
  # the Go server already created schema_migrations with its own layout, so Ecto keeps its list in another table
  migration_source: "ecto_migrations"

config :age3, Age3Web.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  # no HTML pages yet, so errors are rendered as JSON
  render_errors: [formats: [json: Age3Web.ErrorJSON], layout: false]

config :logger, :default_formatter, format: "$time $metadata[$level] $message\n"

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
