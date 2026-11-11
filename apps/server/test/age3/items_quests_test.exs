defmodule Age3.ItemsQuestsTest do
  # Items, the shop and routine quests (the db part runs with mix test --include db).
  use ExUnit.Case, async: true

  alias Age3.{Items, Quests, Repo, Store.Pg}

  test "items: prices, taking, giving and speed-ups" do
    assert Items.price("speed1h", 2) == {:ok, 8000}
    assert Items.price("chest", 1) == {:error, "bad_message"}
    assert Items.price("speed1h", 0) == {:error, "bad_message"}
    assert Items.take(%{"speed1h" => 1}, "speed1h") == {:ok, %{}}
    assert Items.take(%{"speed1h" => 2}, "speed1h") == {:ok, %{"speed1h" => 1}}
    assert Items.take(%{}, "speed1h") == {:error, "no_item"}
    assert Items.give(%{"a" => 1}, %{"a" => 2, "b" => 1}) == %{"a" => 3, "b" => 1}
    assert Items.speed_up("speed1h", "build", 10_000_000, 0) == {:ok, 10_000_000 - 3_600_000}
    assert Items.speed_up("speed1h", "build", 1000, 0) == {:ok, 0}
    assert Items.speed_up("speed1h", "train", 1000, 0) == {:error, "bad_message"}
    assert Items.speed_up("drill30", "train", 1000, 0) == {:ok, 700}
    assert Items.resources("food10k") == %{"food" => 10_000}
    assert Items.resources("speed1h") == nil
  end

  test "quest goals" do
    facts = %{
      buildings: %{"cottage" => 2},
      research: %{},
      troops: %{"warrior" => 50},
      town_hall: 3,
      population: 500,
      prestige: 10,
      cities: 1,
      valleys: 0,
      heroes: 1,
      mayor: false,
      alliance: false,
      title: "knight"
    }

    assert Quests.done?(%{"building" => %{"type" => "cottage", "level" => 2}}, facts)
    refute Quests.done?(%{"troops" => %{"type" => "warrior", "count" => 100}}, facts)
    assert Quests.done?(%{"townHall" => 3}, facts)
    assert Quests.done?(%{"title" => "knight"}, facts)
    refute Quests.done?(%{"title" => "baron"}, facts)
    refute Quests.done?(%{"mayor" => true}, facts)
    # every quest's goal is one done?/2 knows
    for q <- Age3.Data.quests(), do: assert(is_boolean(Quests.done?(q["goal"], facts)))
  end

  describe "in the database" do
    @describetag :db

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
    end

    test "buy, use a speed-up and a resource item, claim a quest once" do
      {:ok, id} = Pg.find_or_create_player("Shopper")
      now = System.system_time(:millisecond)
      {:ok, _, [city], []} = Pg.state(id, now)

      assert :ok = Pg.buy_item(id, city.id, "speed1h", 1, now)
      assert {:error, "not_enough_resources"} = Pg.buy_item(id, city.id, "speed8h", 1, now)
      {:ok, %{items: %{"speed1h" => 1}}, [city], []} = Pg.state(id, now)
      assert_in_delta city.resources["gold"]["amount"], 1000, 1

      # a cottage takes under an hour: the speed-up finishes it
      {:ok, _} = Pg.build(id, city.id, "3", "cottage", now)
      {:ok, _, _, [task]} = Pg.state(id, now)
      assert :ok = Pg.use_item(id, city.id, "speed1h", task.id, now)
      assert {:error, "no_item"} = Pg.use_item(id, city.id, "speed1h", task.id, now)
      {:ok, player, [city], []} = Pg.state(id, now)
      assert %{type: "cottage", level: 1} = Enum.find(city.buildings, &(&1.type == "cottage"))
      assert player.items == %{}

      # the cottage quest is done: its reward (resources and a speed-up) comes once
      assert %{done: true, claimed: false} = Enum.find(Pg.quests(id), &(&1.id == "cottage1"))
      assert {:error, "requirement_not_met"} = Pg.claim_quest(id, city.id, "townhall5", now)
      assert :ok = Pg.claim_quest(id, city.id, "cottage1", now)
      assert {:error, "already_claimed"} = Pg.claim_quest(id, city.id, "cottage1", now)
      {:ok, %{items: %{"speed15m" => 1}}, _, _} = Pg.state(id, now)

      Repo.update_all(Age3.Player, set: [items: %{"food10k" => 1}])
      {:ok, _, [city], _} = Pg.state(id, now)
      food = city.resources["food"]["amount"]
      assert :ok = Pg.use_item(id, city.id, "food10k", nil, now)
      {:ok, _, [city], _} = Pg.state(id, now)
      assert_in_delta city.resources["food"]["amount"], food + 10_000, 1
    end
  end
end
