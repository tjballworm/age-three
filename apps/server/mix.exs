# The game server's project file: name, version, dependencies and build settings (like go.mod).
defmodule Age3.MixProject do
  use Mix.Project

  def project do
    [
      app: :age3,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # The app to start when the server boots, and the Erlang/OTP apps it needs.
  def application do
    [mod: {Age3.Application, []}, extra_applications: [:logger, :runtime_tools]]
  end

  # test/support (the fake store) is compiled only for tests.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # web framework: endpoint, router, controllers
      {:phoenix, "~> 1.8.16"},
      # the HTTP and WebSocket server underneath Phoenix
      {:bandit, "~> 1.13"},
      {:websock_adapter, "~> 0.6"},
      # JSON
      {:jason, "~> 1.4"},
      # database: Ecto (queries, schemas, migrations) and the Postgres driver
      {:ecto_sql, "~> 3.14"},
      {:postgrex, "~> 0.22"}
    ]
  end

  defp aliases do
    [setup: ["deps.get"]]
  end
end
