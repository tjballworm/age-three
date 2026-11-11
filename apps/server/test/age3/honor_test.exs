defmodule Age3.HonorTest do
  # Honor, and leaderboards (the db part runs with mix test --include db).
  use ExUnit.Case, async: true

  alias Age3.{Honor, Repo, Store.Pg}

  test "honor is what the enemy lost less what you lost, per 1,000 resources" do
    assert Honor.troop_value(%{"warrior" => 10}) == 2300
    # killed 100 cavalry (210,000), lost 100 warriors (23,000)
    assert Honor.change(%{"warrior" => 100}, %{"cavalry" => 100}) == 187
    assert Honor.change(%{"cavalry" => 100}, %{"warrior" => 100}) == -187
  end

  describe "in the database" do
    @describetag :db

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
    end

    test "finishing a build gives no prestige; leaderboards and rank go by prestige" do
      {:ok, a} = Pg.find_or_create_player("Builder Bee")
      {:ok, b} = Pg.find_or_create_player("Idle Ida")
      now = System.system_time(:millisecond)
      {:ok, _, [city], []} = Pg.state(a, now)
      {:ok, done} = Pg.build(a, city.id, "3", "cottage", now)
      {:ok, player, _, []} = Pg.state(a, done)
      assert player.prestige == 0

      import Ecto.Query
      Repo.update_all(from(p in Age3.Player, where: p.id == ^a), set: [prestige: 50])
      {:ok, player, _, _} = Pg.state(a, done)
      assert player.rank == 1
      {:ok, other, _, _} = Pg.state(b, done)
      assert other.rank == 2

      assert [%{rank: 1, name: "Builder Bee"}, %{rank: 2, name: "Idle Ida"}] =
               Enum.filter(Pg.leaderboard("player"), &(&1.name in ["Builder Bee", "Idle Ida"]))

      alliance = Repo.insert!(%Age3.Alliance{name: "Bees"})
      Repo.update_all(Age3.Player, set: [alliance_id: alliance.id])
      assert [%{name: "Bees", members: 2}] = Pg.leaderboard("alliance")
      assert Pg.leaderboard("hero") == []
    end
  end
end
