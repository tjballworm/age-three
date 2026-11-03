defmodule Age3.TitlesTest do
  use ExUnit.Case, async: true

  alias Age3.Titles

  @civilian %{military_rank: "civilian", title: "civilian", medals: %{}, prestige: 0}

  test "names and city caps" do
    assert Titles.name(:title, "earl") == "Earl"
    assert Titles.name(:rank, nil) == "Civilian"
    assert Titles.city_cap("civilian") == 1
    assert Titles.city_cap("prinzessin") == 10
    assert Titles.next(:rank, "general") == nil
    assert Titles.next(:title, "civilian")["id"] == "knight"
  end

  test "a rank needs its Town Hall level, medals and gold" do
    assert {:error, "requirement_not_met"} = Titles.check(:rank, @civilian, 10_000, 1)
    assert {:error, "not_enough_resources"} = Titles.check(:rank, @civilian, 9_999, 2)
    assert {:ok, %{"id" => "lieutenant", "gold" => 10_000}} = Titles.check(:rank, @civilian, 10_000, 2)

    lieutenant = %{@civilian | military_rank: "lieutenant"}
    assert {:error, "not_enough_medals"} = Titles.check(:rank, lieutenant, 20_000, 4)

    assert {:ok, %{"id" => "captain"}} =
             Titles.check(:rank, %{lieutenant | medals: %{"cross" => 5}}, 20_000, 4)

    assert {:error, "max_level"} = Titles.check(:rank, %{@civilian | military_rank: "general"}, 10 ** 9, 10)
  end

  test "a title needs its rank and medals; prestige is not checked yet" do
    rich = %{@civilian | medals: %{"cross" => 10, "rose" => 5}}
    assert {:error, "rank_too_low"} = Titles.check(:title, rich, 20_000, 1)
    assert {:ok, step} = Titles.check(:title, %{rich | military_rank: "lieutenant"}, 20_000, 1)
    assert step["id"] == "knight"
    assert Titles.spend(rich.medals, step) == %{}
    assert Titles.add(%{"cross" => 2}, %{"cross" => -1, "nation" => 1}) == %{"cross" => 1, "nation" => 1}
  end

  test "an NPC drops medals only on a full clear of a full NPC, one roll per medal" do
    full = Age3.Npc.full(10)
    wiped = %{defender: %{troops: [%{type: "warrior", survived: 0}]}}
    assert Titles.full_clear?(true, full, full, wiped)
    refute Titles.full_clear?(false, full, full, wiped)
    refute Titles.full_clear?(true, full, full, %{defender: %{troops: [%{type: "warrior", survived: 1}]}})
    refute Titles.full_clear?(true, put_in(full, ["troops", "warrior"], 1), full, wiped)

    assert Titles.roll_npc(10, fn -> 0.0 end) ==
             %{"courage" => 1, "wisdom" => 1, "freedom" => 1, "justice" => 1, "nation" => 1}

    assert Titles.roll_npc(1, fn -> 0.2 end) == %{"cross" => 1}
    assert Titles.roll_npc(1, fn -> 0.99 end) == %{}
  end
end
