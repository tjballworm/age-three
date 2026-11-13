defmodule Age3.HeroesTest do
  use ExUnit.Case, async: true

  alias Age3.Heroes

  defp b(type, level), do: %{type: type, level: level}

  test "the Feasting Hall's level is how many heroes a city holds, the Inn's how many it offers" do
    assert Heroes.capacity([b("feastinghall", 3), b("inn", 2)]) == 3
    assert Heroes.offer_count([b("feastinghall", 3), b("inn", 2)]) == 2
    assert Heroes.capacity([]) == 0
    assert Heroes.offer_count([]) == 0
  end

  test "fee and salary go with the hero's level" do
    assert Heroes.fee(10) == 10_000
    assert Heroes.salary(10) == 200
    assert Heroes.salaries([%{level: 2}, %{level: 10}]) == 240
  end

  test "roll_offers gives Inn-level heroes, the same ones for the same seed" do
    offers = Heroes.roll_offers(3, 42)
    assert length(offers) == 3
    assert offers == Heroes.roll_offers(3, 42)
    assert offers != Heroes.roll_offers(3, 43)
    assert Enum.map(offers, & &1["id"]) == ["42-0", "42-1", "42-2"]

    for o <- offers do
      assert o["level"] in 1..15
      assert is_binary(o["name"])
      # one strong stat (45-80) plus the other two (15-50) plus one point per level
      total = o["politics"] + o["attack"] + o["intelligence"]
      assert total in (45 + 30 + o["level"])..(80 + 100 + o["level"])
      assert Enum.max([o["politics"], o["attack"], o["intelligence"]]) >= 45
    end
  end

  test "current_inn keeps the offers until refreshAt, then rolls new ones on whole steps" do
    step = Heroes.refresh_ms()
    {inn, true} = Heroes.current_inn(%{}, 2, 10, 1)
    assert inn["refreshAt"] == step
    assert inn["level"] == 2
    assert length(inn["offers"]) == 2

    assert {^inn, false} = Heroes.current_inn(inn, 2, step - 1, 2)
    {later, true} = Heroes.current_inn(inn, 2, step, 2)
    assert later["refreshAt"] == 2 * step
    assert later["offers"] != inn["offers"]

    # an upgraded Inn rolls a bigger set straight away, and no Inn has none
    {bigger, true} = Heroes.current_inn(inn, 3, 10, 3)
    assert length(bigger["offers"]) == 3
    assert {%{}, true} = Heroes.current_inn(inn, 0, 10)
    assert {%{}, false} = Heroes.current_inn(%{}, 0, 10)
  end

  test "reroll swaps the offers and keeps the timer" do
    {inn, true} = Heroes.current_inn(%{}, 2, 10, 1)
    new = Heroes.reroll(inn, 2, 7)
    assert new["refreshAt"] == inn["refreshAt"] and new["level"] == 2
    assert new["offers"] == Heroes.roll_offers(2, 7)
    assert new["offers"] != inn["offers"]
  end

  test "check_hire" do
    inn = %{"offers" => [%{"id" => "a", "level" => 5}]}
    city = [b("inn", 1), b("feastinghall", 1)]

    assert {:ok, %{"id" => "a"}} = Heroes.check_hire(city, [], inn, "a", 5_000)
    assert {:error, "not_enough_resources"} = Heroes.check_hire(city, [], inn, "a", 4_999)
    assert {:error, "offer_gone"} = Heroes.check_hire(city, [], inn, "b", 5_000)
    assert {:error, "hall_full"} = Heroes.check_hire(city, [%{level: 1}], inn, "a", 5_000)
    assert {:error, "no_hall"} = Heroes.check_hire([b("inn", 1)], [], inn, "a", 5_000)
    assert {:error, "no_inn"} = Heroes.check_hire([b("feastinghall", 1)], [], inn, "a", 5_000)
    assert Heroes.remove_offer(inn, "a") == %{"offers" => []}
  end

  test "gain_exp levels up as often as the exp covers, with a point each time, and stops at 100" do
    hero = %{level: 1, exp: 0, points: 0}
    assert Heroes.gain_exp(hero, 99) == %{level: 1, exp: 99, points: 0}
    assert Heroes.gain_exp(hero, 100) == %{level: 2, exp: 0, points: 1}
    # 100 to reach Lv2, 400 more to reach Lv3, 50 left over
    assert Heroes.gain_exp(hero, 550) == %{level: 3, exp: 50, points: 2}
    assert Heroes.gain_exp(%{level: 99, exp: 0, points: 0}, 10_000_000) == %{level: 100, exp: 0, points: 1}
    assert Heroes.gain_exp(%{level: 100, exp: 0, points: 3}, 5) == %{level: 100, exp: 0, points: 3}
  end

  test "points go into Politics, Attack and Intelligence, never more than the hero has" do
    h = %{points: 3, politics: 10, attack: 20, intelligence: 30}

    assert Heroes.assign(h, %{"politics" => 2, "intelligence" => 1}) ==
             {:ok,
              [
                points: 0,
                politics: 12,
                attack: 20,
                intelligence: 31,
                added: %{"politics" => 2, "attack" => 0, "intelligence" => 1}
              ]}

    assert Heroes.assign(h, %{"attack" => 4}) == {:error, "not_enough_points"}
    assert Heroes.assign(h, %{"attack" => -1}) == {:error, "bad_message"}
    assert Heroes.assign(h, %{"luck" => 1}) == {:error, "bad_message"}
    assert Heroes.assign(h, %{}) == {:error, "bad_message"}
  end

  test "a mayor's stats speed up builds (Politics), research (Intelligence) and training (Attack)" do
    mayor = %{politics: 100, attack: 100, intelligence: 0}
    assert Heroes.mayor_seconds(1000, nil, :build) == 1000
    assert Heroes.mayor_seconds(1000, mayor, :build) == round(1000 * :math.pow(0.995, 100))
    assert Heroes.mayor_seconds(1000, mayor, :train) == round(1000 * :math.pow(0.9986, 100))
    assert Heroes.mayor_seconds(1000, mayor, :research) == 1000
    assert Heroes.mayor_seconds(1, mayor, :build) == 1
  end

  test "raw cost and the mayor's exp from city work" do
    assert Heroes.raw_cost(%{"food" => 100, "lumber" => 100, "stone" => 100, "iron" => 100, "gold" => 10}) ==
             100 + 100 + 200 + 250 + 100

    assert Heroes.raw_cost(nil) == 0
    assert Heroes.city_work_exp(%{"food" => 1999}) == 9
    assert Heroes.city_work_exp(%{"iron" => 800}) == 10
  end

  test "rewarding a hero: gold or a medal, at most 100, once per 15 minutes" do
    hero = %{level: 10, loyalty: 70, reward_at: nil, status: "idle"}

    assert Heroes.check_reward(hero, "gold", nil, 0, 1_000, %{}) ==
             {:ok, %{gold: 1_000, medal: nil, loyalty: 75}}

    assert Heroes.check_reward(hero, "gold", nil, 0, 999, %{}) == {:error, "not_enough_resources"}

    assert Heroes.check_reward(hero, "medal", "nation", 0, 0, %{"nation" => 1}) ==
             {:ok, %{gold: 0, medal: "nation", loyalty: 100}}

    assert Heroes.check_reward(hero, "medal", "cross", 0, 0, %{}) == {:error, "not_enough_medals"}
    assert Heroes.check_reward(hero, "medal", "gem", 0, 0, %{"gem" => 1}) == {:error, "bad_message"}
    assert Heroes.check_reward(hero, "wine", nil, 0, 0, %{}) == {:error, "bad_message"}

    rewarded = %{hero | reward_at: 1_000}

    assert Heroes.check_reward(rewarded, "gold", nil, 1_000 + 15 * 60_000 - 1, 9_999, %{}) ==
             {:error, "reward_cooldown"}

    assert {:ok, _} = Heroes.check_reward(rewarded, "gold", nil, 1_000 + 15 * 60_000, 9_999, %{})

    assert Heroes.check_reward(%{hero | loyalty: 100}, "gold", nil, 0, 9_999, %{}) == {:error, "loyalty_full"}

    assert Heroes.check_reward(%{hero | status: "captive"}, "gold", nil, 0, 9_999, %{}) ==
             {:error, "hero_busy"}
  end

  test "a lost attack costs 5 loyalty; under 20 the hero is captured if the defender has room" do
    assert Heroes.after_lost_attack(70, true) == {65, false}
    assert Heroes.after_lost_attack(24, true) == {19, true}
    assert Heroes.after_lost_attack(24, false) == {19, false}
    assert Heroes.after_lost_attack(3, false) == {0, false}
  end

  test "reset_points gives back the spent points for level x 1,000 gold, once a day" do
    hero = %{
      level: 5,
      points: 1,
      politics: 12,
      attack: 20,
      intelligence: 31,
      added: %{"politics" => 2, "intelligence" => 1},
      reset_at: nil,
      status: "idle"
    }

    assert Heroes.check_reset(hero, 0, 5_000) ==
             {:ok, [points: 4, politics: 10, attack: 20, intelligence: 30, added: %{}], 5_000}

    assert Heroes.check_reset(hero, 0, 4_999) == {:error, "not_enough_resources"}
    assert Heroes.check_reset(%{hero | added: %{}}, 0, 5_000) == {:error, "nothing_to_reset"}
    assert Heroes.check_reset(%{hero | reset_at: 0}, 86_400_000 - 1, 5_000) == {:error, "reset_cooldown"}
    assert {:ok, _, _} = Heroes.check_reset(%{hero | reset_at: 0}, 86_400_000, 5_000)
  end
end
