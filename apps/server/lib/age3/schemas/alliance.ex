defmodule Age3.Alliance do
  # A row in the alliances table (Age3.Alliances). Members are players with this alliance_id.
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "alliances" do
    field :name, :string
    field :description, :string, default: ""
    # %{other_alliance_id => "friendly" | "hostile"}
    field :diplomacy, :map, default: %{}
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end

defmodule Age3.AllianceRequest do
  # An application to join an alliance (kind "apply") or an invitation from one (kind "invite").
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "alliance_requests" do
    belongs_to :alliance, Age3.Alliance
    belongs_to :player, Age3.Player
    field :kind, :string
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
