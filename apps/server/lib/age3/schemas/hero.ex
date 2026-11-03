defmodule Age3.Hero do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "heroes" do
    belongs_to :city, Age3.City
    field :name, :string
    field :level, :integer, default: 1
    field :exp, :integer, default: 0
    field :points, :integer, default: 0
    field :politics, :integer
    field :attack, :integer
    field :intelligence, :integer
    field :status, :string, default: "idle"
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
