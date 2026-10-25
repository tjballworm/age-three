# Tests tagged :db need Postgres (DATABASE_URL, or apps/server/.env). They are skipped unless asked for:
#   mix test --include db
db? = "--include" in System.argv() and "db" in System.argv()

if db? do
  {:ok, _} = Age3.Repo.start_link()
  Ecto.Migrator.run(Age3.Repo, :up, all: true)
  Ecto.Adapters.SQL.Sandbox.mode(Age3.Repo, :manual)
end

ExUnit.start(exclude: [:db])
