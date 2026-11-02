defmodule Age3.Building do
  # A row in the buildings table: one building in a town or field in its outskirts. slot is "0".."31",
  # "townhall", "walls" or "f0".."f12", and (city_id, slot) is the key, so there is no id column.
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :binary_id
  schema "buildings" do
    belongs_to :city, Age3.City, primary_key: true
    field :slot, :string, primary_key: true
    field :type, :string
    field :level, :integer
  end
end
