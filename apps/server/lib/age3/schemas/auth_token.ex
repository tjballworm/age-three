defmodule Age3.AuthToken do
  # A row in the auth_tokens table: one logged-in browser. The browser keeps the token itself; only its
  # SHA-256 is stored, so someone who reads the database can't use the tokens in it.
  @moduledoc false
  use Ecto.Schema

  @primary_key {:token_hash, :binary, autogenerate: false}
  schema "auth_tokens" do
    belongs_to :player, Age3.Player, type: :binary_id
    timestamps(updated_at: false, type: :utc_datetime)
  end
end
