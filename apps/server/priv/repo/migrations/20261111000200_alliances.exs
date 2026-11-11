defmodule Age3.Repo.Migrations.Alliances do
  # Alliances (Age3.Alliances): a named group of players with a host and ranks, diplomacy with other alliances,
  # and applications/invitations to join.
  #
  # players.alliance_id / alliance_rank: the player's alliance and rank in it (member, officer, presbyter, vice,
  # host). players.alliance stays as the alliance's name, for showing on the map.
  # alliances.diplomacy: %{other_alliance_id => "friendly" | "hostile"}; any other is neutral.
  # alliance_requests: kind "apply" (the player asked to join) or "invite" (the alliance asked the player).
  use Ecto.Migration

  def change do
    create table(:alliances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text, null: false, default: ""
      add :diplomacy, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:alliances, ["lower(name)"], name: :alliances_name_index)

    alter table(:players) do
      add :alliance_id, references(:alliances, type: :binary_id, on_delete: :nilify_all)
      add :alliance_rank, :string
    end

    create index(:players, [:alliance_id])

    create table(:alliance_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :alliance_id, references(:alliances, type: :binary_id, on_delete: :delete_all), null: false
      add :player_id, references(:players, type: :binary_id, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:alliance_requests, [:alliance_id, :player_id])
    create index(:alliance_requests, [:player_id])
  end
end
