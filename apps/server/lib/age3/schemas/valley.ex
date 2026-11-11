defmodule Age3.ValleyHold do
  # A valley held by a player's city (Age3.Valley has the rules).
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "valleys" do
    belongs_to :city, Age3.City
    field :x, :integer
    field :y, :integer
    field :level, :integer
    field :terrain, :string
    field :taken_at, :utc_datetime_usec
  end
end
