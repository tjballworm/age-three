defmodule Age3.Task do
  # A row in the tasks table: something with an end time. Construction (kind "build"): target_type goes to
  # target_level on slot when ends_at passes. Research (kind "research"): the player's tech target_type goes to
  # target_level; slot is nil. Training (kind "train"): target_level troops of type target_type join the city
  # when ends_at passes; slot is the Barracks, and batches waiting in its queue have a started_at in the future.
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
    # marches only: troops, hero, target, loot and phase (Age3.March)
    field :data, :map
    field :started_at, :utc_datetime_usec
    field :ends_at, :utc_datetime_usec
  end
end
