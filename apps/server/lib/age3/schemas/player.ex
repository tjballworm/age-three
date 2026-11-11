defmodule Age3.Player do
  # A row in the players table. An Ecto schema maps a table's columns to an Elixir struct, %Age3.Player{}.
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "players" do
    field :name, :string
    # rank and title ids from priv/data/titles.json ("civilian", "knight"); Age3.Titles
    field :title, :string, default: "civilian"
    field :military_rank, :string, default: "civilian"
    # medals held, e.g. %{"cross" => 3}; medals they have none of are missing
    field :medals, :map, default: %{}

    # the alliance's name, kept for the map; alliance_id and alliance_rank say which and what rank (Age3.Alliances)
    field :alliance, :string
    field :alliance_id, :binary_id
    field :alliance_rank, :string
    field :prestige, :integer, default: 0
    field :honor, :integer, default: 0
    # research levels for all the player's cities, e.g. %{"agriculture" => 2}; missing techs are level 0
    field :research, :map, default: %{}
    field :instant_march, :boolean, default: false
    # items held, %{"speed1h" => 2}; quests whose reward was claimed (Age3.Items, Age3.Quests)
    field :items, :map, default: %{}
    field :quests, {:array, :string}, default: []
    # from Age3.Password; nil means this player can't log in yet. redact: true keeps it out of logs
    field :password_hash, :string, redact: true
    has_many :cities, Age3.City
  end
end
