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
    # gear stars, 0-15 (battle multipliers in Age3.Combat.Units.star_multipliers)
    field :stars, :integer, default: 0
    field :status, :string, default: "idle"
    # 0-100: hired heroes start at 70, captives at 0 (Age3.Heroes.check_reward, after_lost_attack)
    field :loyalty, :integer, default: 70
    field :reward_at, :utc_datetime_usec
    # stat points the player spent, by stat, so reset_points can give them back
    field :added, :map, default: %{}
    field :reset_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
