defmodule Age3.Repo.Migrations.AddLogins do
  # Username + password logins. Players without a password_hash can't log in until one is set
  # (Age3.Accounts.set_password/2). auth_tokens holds one row per logged-in browser.
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :password_hash, :text
    end

    create table(:auth_tokens, primary_key: false) do
      add :token_hash, :binary, primary_key: true
      add :player_id, references(:players, type: :uuid, on_delete: :delete_all), null: false
      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:auth_tokens, [:player_id])
  end
end
