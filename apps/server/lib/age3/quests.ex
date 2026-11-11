defmodule Age3.Quests do
  # Routine quests as pure functions (priv/data/quests.json, after the wiki's Routine Quest page). A quest is done
  # when its goal holds for the player now (facts, gathered by the store); its reward is claimed once, into a
  # city of the player's choice.
  @moduledoc false

  alias Age3.{Data, Titles}

  @doc "The quest with this id, or nil."
  def quest(id), do: Enum.find(Data.quests(), &(&1["id"] == id))

  @doc """
  Does the goal hold? facts: %{buildings: %{type => best level}, research, troops: %{type => n}, town_hall (best),
  population (best limit), prestige, cities, valleys, heroes, mayor (bool), alliance (bool), title}.
  """
  def done?(%{"building" => %{"type" => t, "level" => l}}, f), do: Map.get(f.buildings, t, 0) >= l
  def done?(%{"research" => %{"tech" => t, "level" => l}}, f), do: Map.get(f.research || %{}, t, 0) >= l
  def done?(%{"troops" => %{"type" => t, "count" => n}}, f), do: Map.get(f.troops, t, 0) >= n
  def done?(%{"townHall" => l}, f), do: f.town_hall >= l
  def done?(%{"population" => n}, f), do: f.population >= n
  def done?(%{"prestige" => n}, f), do: f.prestige >= n
  def done?(%{"cities" => n}, f), do: f.cities >= n
  def done?(%{"valleys" => n}, f), do: f.valleys >= n
  def done?(%{"heroes" => n}, f), do: f.heroes >= n
  def done?(%{"mayor" => true}, f), do: f.mayor
  def done?(%{"alliance" => true}, f), do: f.alliance
  def done?(%{"title" => t}, f), do: Titles.rank_of(:title, f.title) >= Titles.rank_of(:title, t)
  def done?(_goal, _facts), do: false

  @doc "Every quest with whether it is done and claimed: [%{id, category, name, goal, reward, done, claimed}]."
  def status(facts, claimed) do
    for q <- Data.quests() do
      %{
        id: q["id"],
        category: q["category"],
        name: q["name"],
        goal: q["goal"],
        reward: q["reward"],
        done: done?(q["goal"], facts),
        claimed: q["id"] in claimed
      }
    end
  end
end
