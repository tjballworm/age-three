defmodule Age3.ChatMessage do
  # A chat line in the world channel (alliance_id nil) or an alliance's (Age3.Social).
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_messages" do
    field :alliance_id, :binary_id
    field :player_id, :binary_id
    field :name, :string
    field :text, :string
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end

defmodule Age3.Mail do
  # A mail between players (Age3.Social); from_id nil is mail from the game.
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "mails" do
    field :from_id, :binary_id
    field :to_id, :binary_id
    field :from_name, :string
    field :to_name, :string
    field :subject, :string
    field :body, :string
    field :read, :boolean, default: false
    field :sender_deleted, :boolean, default: false
    field :receiver_deleted, :boolean, default: false
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
