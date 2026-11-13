defmodule Age3.FakeStore do
  # A store with no database, for the session tests. One account: "Lord TJ" with password "secret123".
  @moduledoc false
  @behaviour Age3.Store

  @impl true
  def authenticate("Lord TJ", "secret123"), do: {:ok, "p1"}
  def authenticate(_name, _password), do: :error

  @impl true
  def new_token("p1"), do: "t1"

  @impl true
  def player_for_token("t1"), do: {:ok, "p1"}
  def player_for_token(_token), do: :error

  @impl true
  def state(id, _now_ms), do: {:ok, %{id: id, name: "Lord TJ"}, [], []}

  # slot "0" can always be built; anything else is busy
  @impl true
  def build(_player_id, _city_id, "0", _type, now_ms), do: {:ok, now_ms + 45_000}
  def build(_player_id, _city_id, _slot, _type, _now_ms), do: {:error, "queue_busy"}

  @impl true
  def cancel_build(_player_id, _city_id, "t1", _now_ms), do: :ok
  def cancel_build(_player_id, _city_id, _task_id, _now_ms), do: {:error, "bad_message"}

  # city "c1" can always be promoted; anything else lacks medals
  @impl true
  def promote(_player_id, "c1", _ladder, _now_ms), do: :ok
  def promote(_player_id, _city_id, _ladder, _now_ms), do: {:error, "not_enough_medals"}

  # city "c1" can always comfort; anything else is still cooling down
  @impl true
  def comfort(_player_id, "c1", kind, _now_ms) when kind in ["relief", "pray", "bless", "raise"], do: :ok
  def comfort(_player_id, _city_id, _kind, _now_ms), do: {:error, "comfort_cooldown"}

  # city "c1" can always levy; anything else is still cooling down
  @impl true
  def levy(_player_id, "c1", kind, _now_ms) when kind in ["gold", "food", "lumber", "stone", "iron"], do: :ok
  def levy(_player_id, "c1", _kind, _now_ms), do: {:error, "bad_message"}
  def levy(_player_id, _city_id, _kind, _now_ms), do: {:error, "levy_cooldown"}

  @impl true
  def rename_city(_player_id, "c1", _name, _now_ms), do: :ok
  def rename_city(_player_id, _city_id, _name, _now_ms), do: {:error, "bad_message"}

  # anything on slot "3" can be demolished; the Town Hall can't
  @impl true
  def demolish(_player_id, _city_id, "3", now_ms), do: {:ok, now_ms + 30_000}
  def demolish(_player_id, _city_id, "townhall", _now_ms), do: {:error, "cant_demolish"}
  def demolish(_player_id, _city_id, _slot, _now_ms), do: {:error, "bad_slot"}

  @impl true
  def abandon_city(_player_id, "c2", "c1", _now_ms), do: {:ok, 1}
  def abandon_city(_player_id, _city_id, _move_to, _now_ms), do: {:error, "troops_out"}

  @impl true
  def set_gate(_player_id, "c1", open, _now_ms) when is_boolean(open), do: :ok
  def set_gate(_player_id, _city_id, _open, _now_ms), do: {:error, "bad_message"}

  @impl true
  def heal(_player_id, "c1", %{"warrior" => n}, _now_ms) when is_integer(n) and n > 0, do: :ok
  def heal(_player_id, _city_id, _troops, _now_ms), do: {:error, "not_enough_wounded"}

  @impl true
  def set_defender(_player_id, "c1", hero_id, _now_ms) when hero_id in ["h1", nil], do: :ok
  def set_defender(_player_id, _city_id, _hero_id, _now_ms), do: {:error, "bad_message"}

  @impl true
  def persuade(_player_id, "c1", "h1", _now_ms), do: :ok
  def persuade(_player_id, _city_id, _hero_id, _now_ms), do: {:error, "not_enough_resources"}

  @impl true
  def lords(_player_id), do: [%{id: "c9", name: "Other's Town", x: 5, y: 6, level: 1, owner: "Other"}]

  @impl true
  def set_tax(_player_id, "c1", _tax_rate, _now_ms), do: :ok
  def set_tax(_player_id, _city_id, _tax_rate, _now_ms), do: {:error, "bad_message"}

  # "agriculture" can always be researched; anything else needs a bigger Academy
  @impl true
  def research(_player_id, _city_id, "agriculture", now_ms), do: {:ok, now_ms + 400_000}
  def research(_player_id, _city_id, _tech, _now_ms), do: {:error, "requirement_not_met"}

  @impl true
  def cancel_research(_player_id, _city_id, "t1", _now_ms), do: :ok
  def cancel_research(_player_id, _city_id, _task_id, _now_ms), do: {:error, "bad_message"}

  # 10 warriors in the Barracks on plot 4 can always be trained; anything else needs a bigger Barracks
  @impl true
  def train(_player_id, _city_id, "4", "warrior", 10, now_ms), do: {:ok, now_ms + 250_000}
  def train(_player_id, _city_id, _slot, _troop, _count, _now_ms), do: {:error, "requirement_not_met"}

  @impl true
  def cancel_train(_player_id, _city_id, "t1", _now_ms), do: :ok
  def cancel_train(_player_id, _city_id, _task_id, _now_ms), do: {:error, "bad_message"}

  @impl true
  def build_forts(_player_id, _city_id, "trap", 10, now_ms), do: {:ok, now_ms + 60_000}
  def build_forts(_player_id, _city_id, _fort, _count, _now_ms), do: {:error, "no_wall_space"}

  @impl true
  def cancel_forts(_player_id, _city_id, "t1", _now_ms), do: :ok
  def cancel_forts(_player_id, _city_id, _task_id, _now_ms), do: {:error, "bad_message"}

  @impl true
  def assign_points(_player_id, _city_id, "h1", %{"politics" => 1}, _now_ms), do: :ok
  def assign_points(_player_id, _city_id, _hero_id, _add, _now_ms), do: {:error, "not_enough_points"}

  @impl true
  def reward_hero(_player_id, "c1", "h1", "gold", nil, _now_ms), do: :ok
  def reward_hero(_player_id, "c1", "h1", "medal", "cross", _now_ms), do: :ok
  def reward_hero(_player_id, _city_id, _hero_id, _kind, _medal, _now_ms), do: {:error, "reward_cooldown"}

  @impl true
  def rename_hero(_player_id, "c1", "h1", _name, _now_ms), do: :ok
  def rename_hero(_player_id, _city_id, _hero_id, _name, _now_ms), do: {:error, "bad_message"}

  @impl true
  def reset_points(_player_id, "c1", "h1", _now_ms), do: :ok
  def reset_points(_player_id, _city_id, _hero_id, _now_ms), do: {:error, "nothing_to_reset"}

  @impl true
  def alliance_info(_player_id), do: %{alliance: nil, invites: [], applied: [], embassy: 1, alliances: []}

  @impl true
  def alliance_action(_player_id, "apply", %{"name" => "Pact"}, _now_ms), do: :ok
  def alliance_action(_player_id, _action, _args, _now_ms), do: {:error, "no_alliance"}

  @impl true
  def chat(_player_id, "world", "hi", now_ms),
    do: {:ok, %{id: "l1", channel: "world", from: "Tester", text: "hi", at: now_ms}, :all}

  def chat(_player_id, _channel, _text, _now_ms), do: {:error, "no_alliance"}

  @impl true
  def chat_history(_player_id), do: []

  @impl true
  def chat_audience(_to), do: []

  @impl true
  def send_mail(_player_id, "Other", _subject, _body, _now_ms), do: {:ok, "p2"}
  def send_mail(_player_id, _to, _subject, _body, _now_ms), do: {:error, "player_not_found"}

  @impl true
  def mailbox(_player_id), do: %{inbox: [], sent: []}

  @impl true
  def read_mail(_player_id, "m1"), do: :ok
  def read_mail(_player_id, _mail_id), do: {:error, "bad_message"}

  @impl true
  def delete_mail(_player_id, _mail_id), do: :ok

  @impl true
  def market(_player_id, "c1"), do: {:ok, %{level: 1, books: %{}, orders: []}}
  def market(_player_id, _city_id), do: {:error, "bad_message"}

  @impl true
  def place_order(_player_id, "c1", "sell", "food", 100, 50, _now_ms), do: {:ok, []}
  def place_order(_player_id, _city_id, _side, _r, _amount, _price, _now_ms), do: {:error, "market_full"}

  @impl true
  def cancel_order(_player_id, _city_id, _order_id, _now_ms), do: :ok

  @impl true
  def leaderboard(board), do: [%{rank: 1, name: board}]

  @impl true
  def buy_item(_player_id, _city_id, "speed1h", 1, _now_ms), do: :ok
  def buy_item(_player_id, _city_id, _item, _count, _now_ms), do: {:error, "not_enough_resources"}

  @impl true
  def use_item(_player_id, _city_id, "speed1h", "t1", _now_ms), do: :ok
  def use_item(_player_id, _city_id, _item, _task_id, _now_ms), do: {:error, "no_item"}

  @impl true
  def quests(_player_id), do: [%{id: "cottage1", done: true, claimed: false}]

  @impl true
  def claim_quest(_player_id, _city_id, "cottage1", _now_ms), do: :ok
  def claim_quest(_player_id, _city_id, _quest_id, _now_ms), do: {:error, "already_claimed"}

  # task "t1" has under 5 minutes left; "t2" has more
  @impl true
  def speed_up(_player_id, _city_id, "t1", _now_ms), do: :ok
  def speed_up(_player_id, _city_id, "t2", _now_ms), do: {:error, "too_early"}
  def speed_up(_player_id, _city_id, _task_id, _now_ms), do: {:error, "bad_message"}

  # cheats work on city "c1" and on the player "Other" (id "p2"); anyone else isn't found
  @impl true
  def cheat("p1", {:city, "c1"}, _action, _args, _now_ms), do: {:ok, "p1"}
  def cheat(_player_id, {:player, "Other"}, _action, _args, _now_ms), do: {:ok, "p2"}
  def cheat(_player_id, {:player, _name}, _action, _args, _now_ms), do: {:error, "player_not_found"}
  def cheat(_player_id, _target, _action, _args, _now_ms), do: {:error, "bad_message"}

  # offer "o1" can always be hired, hero "h1" dismissed or appointed (or no mayor at all); anything else is gone
  @impl true
  def hire(_player_id, _city_id, "o1", _now_ms), do: :ok
  def hire(_player_id, _city_id, _offer_id, _now_ms), do: {:error, "offer_gone"}

  @impl true
  def reroll_inn(_player_id, "c1", _now_ms), do: :ok
  def reroll_inn(_player_id, _city_id, _now_ms), do: {:error, "no_inn"}

  @impl true
  def dismiss(_player_id, _city_id, "h1", _now_ms), do: :ok
  def dismiss(_player_id, _city_id, _hero_id, _now_ms), do: {:error, "hero_busy"}

  @impl true
  def set_mayor(_player_id, _city_id, hero_id, _now_ms) when hero_id in ["h1", nil], do: :ok
  def set_mayor(_player_id, _city_id, _hero_id, _now_ms), do: {:error, "bad_message"}

  @impl true
  def march(_player_id, "c1", 10, 20, "h1", %{"warrior" => 100}, now_ms, %{
        "camp" => camp,
        "mission" => "attack"
      }),
      do: {:ok, now_ms + (60 + camp) * 1000}

  def march(_player_id, "c1", 10, 20, nil, %{"scout" => 10}, now_ms, %{"mission" => "scout"}),
    do: {:ok, now_ms + 5000}

  def march(_player_id, _city_id, _x, _y, _hero_id, _troops, _now_ms, _camp), do: {:error, "bad_target"}

  @impl true
  def impose_policy(_player_id, "c1", 10, 20, "tax", _now_ms), do: :ok
  def impose_policy(_player_id, _city_id, _x, _y, _policy, _now_ms), do: {:error, "not_historic"}

  @impl true
  def recall(_player_id, "c1", "m1", now_ms), do: {:ok, now_ms + 30_000}
  def recall(_player_id, _city_id, _task_id, _now_ms), do: {:error, "already_returning"}

  @impl true
  def reports(_player_id), do: [%{id: "r1", title: "Victory against Lv1 NPC (10,20)", won: true, read: false}]

  @impl true
  def report(_player_id, "r1"), do: {:ok, %{id: "r1", won: true, result: %{"winner" => "attacker"}}}
  def report(_player_id, _report_id), do: {:error, "bad_message"}

  @impl true
  def set_garrison(_player_id, "c1", _allow, _now_ms), do: :ok
  def set_garrison(_player_id, _city_id, _allow, _now_ms), do: {:error, "bad_message"}

  @impl true
  def abandon_valley(_player_id, "c1", 1, 2, _now_ms), do: :ok
  def abandon_valley(_player_id, _city_id, _x, _y, _now_ms), do: {:error, "bad_message"}
end
