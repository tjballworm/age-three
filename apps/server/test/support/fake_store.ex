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
  def dismiss(_player_id, _city_id, "h1", _now_ms), do: :ok
  def dismiss(_player_id, _city_id, _hero_id, _now_ms), do: {:error, "hero_busy"}

  @impl true
  def set_mayor(_player_id, _city_id, hero_id, _now_ms) when hero_id in ["h1", nil], do: :ok
  def set_mayor(_player_id, _city_id, _hero_id, _now_ms), do: {:error, "bad_message"}

  @impl true
  def march(_player_id, "c1", 10, 20, "h1", %{"warrior" => 100}, now_ms), do: {:ok, now_ms + 60_000}
  def march(_player_id, _city_id, _x, _y, _hero_id, _troops, _now_ms), do: {:error, "bad_target"}

  @impl true
  def recall(_player_id, "c1", "m1", now_ms), do: {:ok, now_ms + 30_000}
  def recall(_player_id, _city_id, _task_id, _now_ms), do: {:error, "already_returning"}

  @impl true
  def reports(_player_id), do: [%{id: "r1", title: "Victory against Lv1 NPC (10,20)", won: true, read: false}]

  @impl true
  def report(_player_id, "r1"), do: {:ok, %{id: "r1", won: true, result: %{"winner" => "attacker"}}}
  def report(_player_id, _report_id), do: {:error, "bad_message"}
end
