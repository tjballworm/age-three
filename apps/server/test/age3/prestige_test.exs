defmodule Age3.PrestigeTest do
  # Prestige, honor and leaderboards (the db part runs with mix test --include db).
  use ExUnit.Case, async: true

  alias Age3.{Prestige, Repo, Store.Pg}

  test "prestige from costs per Town Hall level, battles and honor" do
    # 3 warriors cost 690: 3 experience, 1 prestige with a Lv3 Town Hall (the wiki's example)
    assert Prestige.for_cost(%{"food" => 240, "lumber" => 300, "iron" => 150}, 3) == 1
    assert Prestige.for_cost(%{"gold" => 10_000}, 1) == 50
    assert Prestige.for_cost(%{}, 0) == 0
    assert Prestige.troop_value(%{"warrior" => 10}) == 2300
    # killed 100 cavalry (210,000), lost 100 warriors (23,000)
    assert Prestige.battle(%{"warrior" => 100}, %{"cavalry" => 100}, 1) == 1050 - 115
    assert Prestige.honor(%{"warrior" => 100}, %{"cavalry" => 100}) == 187
    assert Prestige.honor(%{"cavalry" => 100}, %{"warrior" => 100}) == -187
  end

  describe "in the database" do
    @describetag :db

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
    end

    test "finishing a build gives prestige, and the leaderboards rank by it" do
      {:ok, a} = Pg.find_or_create_player("Builder Bee")
      {:ok, b} = Pg.find_or_create_player("Idle Ida")
      now = System.system_time(:millisecond)
      {:ok, _, [city], []} = Pg.state(a, now)
      {:ok, done} = Pg.build(a, city.id, "3", "cottage", now)
      {:ok, player, _, []} = Pg.state(a, done)
      assert player.prestige > 0
      assert player.rank == 1
      {:ok, other, _, _} = Pg.state(b, done)
      assert other.rank == 2

      assert [%{rank: 1, name: "Builder Bee"}, %{rank: 2, name: "Idle Ida"} | _] =
               Enum.filter(Pg.leaderboard("player"), &(&1.name in ["Builder Bee", "Idle Ida"]))

      alliance = Repo.insert!(%Age3.Alliance{name: "Bees"})
      Repo.update_all(Age3.Player, set: [alliance_id: alliance.id])
      assert [%{name: "Bees", members: 2}] = Pg.leaderboard("alliance")
      assert Pg.leaderboard("hero") == []
    end
  end
end
