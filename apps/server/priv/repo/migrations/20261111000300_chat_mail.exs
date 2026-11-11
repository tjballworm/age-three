defmodule Age3.Repo.Migrations.ChatMail do
  # Server chat and mail (Age3.Social).
  #
  # chat_messages: the world channel (alliance_id null) and each alliance's channel; only the latest are read.
  # mails: player-to-player mail. from_id is null for mail from the game. Each side can delete its copy; the row
  # goes when both have.
  use Ecto.Migration

  def change do
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :alliance_id, references(:alliances, type: :binary_id, on_delete: :delete_all)
      add :player_id, references(:players, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :text, :string, size: 200, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:chat_messages, [:alliance_id, :inserted_at])

    create table(:mails, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :from_id, references(:players, type: :binary_id, on_delete: :nilify_all)
      add :to_id, references(:players, type: :binary_id, on_delete: :delete_all), null: false
      add :from_name, :string, null: false
      add :to_name, :string, null: false
      add :subject, :string, size: 100, null: false
      add :body, :text, null: false
      add :read, :boolean, null: false, default: false
      add :sender_deleted, :boolean, null: false, default: false
      add :receiver_deleted, :boolean, null: false, default: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:mails, [:to_id, :inserted_at])
    create index(:mails, [:from_id, :inserted_at])
  end
end
