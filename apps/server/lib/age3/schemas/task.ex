defmodule Age3.Task do
  # A row in the tasks table: something with an end time. For now only construction (kind "build"): target_type
  # goes to target_level on slot when ends_at passes.
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tasks" do
    belongs_to :city, Age3.City
    field :kind, :string
    field :label, :string
    field :slot, :string
    field :target_type, :string
    field :target_level, :integer
    field :cost, :map
    field :started_at, :utc_datetime_usec
    field :ends_at, :utc_datetime_usec
  end
end
