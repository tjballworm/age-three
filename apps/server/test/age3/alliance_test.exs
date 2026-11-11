defmodule Age3.AllianceTest do
  # Alliances: the pure rules, and founding, joining, ranks, diplomacy and attacks against Postgres.
  # The db tests run with: mix test --include db
  use ExUnit.Case, async: true

  alias Age3.{Alliances, Building, City, Repo, Store.Pg}

  describe "rules" do
    test "ranks and powers" do
      assert Alliances.rank_value("host") == 5
      assert Alliances.rank_value(nil) == 0
      assert Alliances.can?("officer", :accept)
      refute Alliances.can?("member", :invite)
      refute Alliances.can?("officer", :kick)
      assert Alliances.can?("vice", :diplomacy)
      refute Alliances.can?("vice", :disband)
      assert Alliances.above?("vice", "presbyter")
      refute Alliances.above?("officer", "officer")
    end

    test "names, member caps and relations" do
      assert Alliances.name("  The Pact ") == {:ok, "The Pact"}
      assert Alliances.name("ab") == {:error, "bad_name"}
      assert Alliances.name("<script>") == {:error, "bad_name"}
      assert Alliances.member_cap(0) == 10
      assert Alliances.member_cap(3) == 30
      assert Alliances.member_cap(12) == 100
      assert Alliances.relation("a", "a", %{}) == "alliance"
      assert Alliances.relation("a", "b", %{"b" => "hostile"}) == "hostile"
      assert Alliances.relation("a", nil, %{}) == nil
      refute Alliances.may_attack?("a", "b", %{"b" => "friendly"})
    end
  end

  describe "in the database" do
    @describetag :db

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
    end

    defp lord(name, embassy) do
      {:ok, id} = Pg.find_or_create_player(name)
      now = System.system_time(:millisecond)
      {:ok, _, [city], []} = Pg.state(id, now)

      if embassy > 0,
        do: Repo.insert!(%Building{city_id: city.id, slot: "5", type: "embassy", level: embassy})

      Repo.query!(
        "UPDATE cities SET resources = jsonb_set(resources, '{gold,amount}', '50000') WHERE id = $1",
        [
          Ecto.UUID.dump!(city.id)
        ]
      )

      %{id: id, city: Repo.get!(City, city.id), now: now}
    end

    defp act(l, action, args \\ %{}), do: Pg.alliance_action(l.id, action, args, l.now)

    test "found, apply, accept, ranks, leave and disband" do
      host = lord("Founder", 2)
      joiner = lord("Joiner", 2)
      nobody = lord("No Embassy", 0)

      assert {:error, "requirement_not_met"} =
               act(nobody, "create", %{"cityId" => nobody.city.id, "name" => "Nope"})

      assert :ok = act(host, "create", %{"cityId" => host.city.id, "name" => "The Pact"})
      {:ok, _, [city], _} = Pg.state(host.id, host.now)
      assert_in_delta city.resources["gold"]["amount"], 40_000, 5

      assert {:error, "name_taken"} =
               act(joiner, "create", %{"cityId" => joiner.city.id, "name" => "the pact"})

      assert {:error, "no_embassy"} = act(nobody, "apply", %{"name" => "The Pact"})
      assert :ok = act(joiner, "apply", %{"name" => "the pact"})
      %{alliance: %{applications: [app], members: [_]}} = Pg.alliance_info(host.id)
      assert app.player == "Joiner"
      assert {:error, "no_alliance"} = act(joiner, "setRank", %{"player" => "Founder", "rank" => "member"})
      assert :ok = act(host, "accept", %{"requestId" => app.id})

      %{alliance: a} = Pg.alliance_info(joiner.id)
      assert a.name == "The Pact" and a.rank == "member" and length(a.members) == 2
      assert {:error, "rank_too_low"} = act(joiner, "kick", %{"player" => "Founder"})
      assert :ok = act(host, "setRank", %{"player" => "Joiner", "rank" => "vice"})
      assert {:error, "rank_too_low"} = act(joiner, "setRank", %{"player" => "Founder", "rank" => "member"})

      # the host leaves: the vice host takes over
      assert :ok = act(host, "leave")
      assert %{alliance: %{rank: "host", members: [_]}} = Pg.alliance_info(joiner.id)
      assert :ok = act(joiner, "disband")
      assert %{alliance: nil, alliances: []} = Pg.alliance_info(joiner.id)
    end

    test "invitations, the member cap, and no attacks on members or friendly alliances" do
      host = lord("Inviter", 2)
      guest = lord("Guest", 1)
      other = lord("Outsider", 2)
      :ok = act(host, "create", %{"cityId" => host.city.id, "name" => "Hosts"})
      :ok = act(other, "create", %{"cityId" => other.city.id, "name" => "Others"})

      assert :ok = act(host, "invite", %{"player" => "Guest"})
      %{invites: [invite]} = Pg.alliance_info(guest.id)
      assert invite.alliance == "Hosts"

      # pretend the alliance is full: the cap is 10 per Embassy level of the host (Lv2 = 20)
      %{alliance: %{id: aid, memberCap: 20}} = Pg.alliance_info(host.id)

      fillers =
        for i <- 1..19 do
          {:ok, id} = Pg.find_or_create_player("Filler #{i}")
          id
        end

      import Ecto.Query

      Repo.update_all(from(p in Age3.Player, where: p.id in ^fillers),
        set: [alliance_id: aid, alliance_rank: "member"]
      )

      assert {:error, "alliance_full"} = act(guest, "accept", %{"requestId" => invite.id})

      Repo.update_all(from(p in Age3.Player, where: p.id in ^fillers),
        set: [alliance_id: nil, alliance_rank: nil]
      )

      assert :ok = act(guest, "accept", %{"requestId" => invite.id})

      # can't attack a member; can attack another alliance until it is called friendly
      Repo.insert!(%Building{city_id: host.city.id, slot: "1", type: "rallyspot", level: 5})
      {:ok, _} = Pg.cheat(host.id, {:city, host.city.id}, "addTroops", %{troops: %{"scout" => 100}}, host.now)

      scout = fn to ->
        Pg.march(host.id, host.city.id, to.city.x, to.city.y, nil, %{"scout" => 10}, host.now, %{
          "mission" => "scout"
        })
      end

      assert {:error, "friendly"} = scout.(guest)
      assert {:ok, _} = scout.(other)
      assert :ok = act(host, "diplomacy", %{"name" => "Others", "status" => "friendly"})
      assert {:error, "friendly"} = scout.(other)
      [lord] = Enum.filter(Pg.lords(host.id), &(&1.owner == "Outsider"))
      assert lord.relation == "friendly"
      assert :ok = act(host, "diplomacy", %{"name" => "Others", "status" => "neutral"})
      assert %{alliance: %{diplomacy: []}} = Pg.alliance_info(host.id)
    end
  end
end
