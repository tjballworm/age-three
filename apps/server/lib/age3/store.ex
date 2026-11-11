defmodule Age3.Store do
  # All database access (like internal/store). The session calls whichever module implements these callbacks,
  # so tests can swap in a fake without a database. A behaviour is Elixir's version of a Go interface.
  @moduledoc false

  @doc "The player's id if the username and password match."
  @callback authenticate(name :: String.t(), password :: String.t()) ::
              {:ok, player_id :: String.t()} | :error

  @doc "A new login token for the player, for the browser to keep."
  @callback new_token(player_id :: String.t()) :: token :: String.t()

  @doc "The player a login token belongs to, if it's still valid."
  @callback player_for_token(token :: String.t()) :: {:ok, player_id :: String.t()} | :error

  @doc """
  The player, all their cities with buildings and fields, and their cities' running tasks, shaped as the client's
  JSON, with resources as at now_ms. Tasks already due are finished first.
  """
  @callback state(player_id :: String.t(), now_ms :: integer) ::
              {:ok, player :: map, cities :: [map], tasks :: [map]} | {:error, :not_found}

  @doc """
  Starts building type on slot in one of the player's cities, or upgrading what stands there (type nil), paying
  the cost now. Returns when it will finish.
  """
  @callback build(
              player_id :: String.t(),
              city_id :: String.t(),
              slot :: String.t(),
              type :: String.t() | nil,
              now_ms :: integer
            ) :: {:ok, ends_at_ms :: integer} | {:error, code :: String.t()}

  @doc """
  Starts researching the next level of tech in one of the player's cities, in its Academy, paying the cost now.
  Returns when it will finish.
  """
  @callback research(player_id :: String.t(), city_id :: String.t(), tech :: String.t(), now_ms :: integer) ::
              {:ok, ends_at_ms :: integer} | {:error, code :: String.t()}

  @doc "Stops a research that hasn't finished and refunds its whole cost."
  @callback cancel_research(
              player_id :: String.t(),
              city_id :: String.t(),
              task_id :: String.t(),
              now_ms :: integer
            ) :: :ok | {:error, code :: String.t()}

  @doc """
  Queues count troops in the Barracks on slot in one of the player's cities, paying the cost and taking the idle
  population now. The batch starts when the ones before it in that Barracks finish. Returns when it will finish.
  """
  @callback train(
              player_id :: String.t(),
              city_id :: String.t(),
              slot :: String.t(),
              troop :: String.t(),
              count :: integer,
              now_ms :: integer
            ) :: {:ok, ends_at_ms :: integer} | {:error, code :: String.t()}

  @doc """
  Stops a training batch (running or waiting) and refunds its whole cost and population. The batches behind it
  in that Barracks move up.
  """
  @callback cancel_train(
              player_id :: String.t(),
              city_id :: String.t(),
              task_id :: String.t(),
              now_ms :: integer
            ) :: :ok | {:error, code :: String.t()}

  @doc """
  Finishes a building's construction or upgrade for free when it has Data.free_speedup_ms/0 or less left. Research,
  training and walls never get it (no_free_speedup).
  """
  @callback speed_up(player_id :: String.t(), city_id :: String.t(), task_id :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc """
  Promotes the player one step up the rank (ladder :rank) or title (:title) ladder, paying the gold from city_id
  (whose Town Hall level counts for ranks) and the medals now. Adds the step's prestige award.
  """
  @callback promote(
              player_id :: String.t(),
              city_id :: String.t(),
              ladder :: :rank | :title,
              now_ms :: integer
            ) ::
              :ok | {:error, code :: String.t()}

  @doc """
  Comforts a city's people (Age3.Loyalty): kind "relief" (Disaster Relief, food) or "pray" (Praying, gold), once
  every 15 minutes per city. Pays the population limit in that resource and raises loyalty / lowers grievance.
  """
  @callback comfort(player_id :: String.t(), city_id :: String.t(), kind :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc """
  Opens or closes a city's gate (the Rally Spot's "open gate to fight"). Closed, the troops stay out of battles and
  only the walls defend; the gate opens by itself at loyalty 5 or less.
  """
  @callback set_gate(player_id :: String.t(), city_id :: String.t(), open :: boolean, now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc "Chooses the hero who leads a city's defence (any free hero in the city, the mayor too), or nobody (nil)."
  @callback set_defender(
              player_id :: String.t(),
              city_id :: String.t(),
              hero_id :: String.t() | nil,
              now_ms :: integer
            ) :: :ok | {:error, code :: String.t()}

  @doc """
  Persuades a captive hero (from a captured city) to join: pays their hiring fee (level x 1,000 gold) from that
  city. Releasing a captive is dismiss/4.
  """
  @callback persuade(player_id :: String.t(), city_id :: String.t(), hero_id :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc "Every other player's cities, for the world map: id, name, x, y, level and owner."
  @callback lords(player_id :: String.t()) :: [map]

  @doc "Sets a city's tax rate (0-100). Gold from taxes changes from now on."
  @callback set_tax(player_id :: String.t(), city_id :: String.t(), tax_rate :: integer, now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc """
  A testing command from Age3.Cheats (action and its parsed args). target is {:city, city_id} for one of the
  player's own cities, or {:player, name} for every city of any player (and their research). No permission check:
  any player can cheat on any account. Returns the id of the player whose game changed.
  """
  @callback cheat(
              player_id :: String.t(),
              target :: {:city, String.t()} | {:player, String.t()},
              action :: String.t(),
              args :: map,
              now_ms :: integer
            ) :: {:ok, target_player_id :: String.t()} | {:error, code :: String.t()}

  @doc """
  Hires the hero the city's Inn offers under offer_id into its Feasting Hall, paying the fee in gold now. The
  hero's salary comes off the city's gold rate from now on.
  """
  @callback hire(player_id :: String.t(), city_id :: String.t(), offer_id :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc "Swaps the city's Inn offers for a new set now, for free. The timed refresh stays where it was."
  @callback reroll_inn(player_id :: String.t(), city_id :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc "Sends an idle hero away for good. Their salary stops."
  @callback dismiss(player_id :: String.t(), city_id :: String.t(), hero_id :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc "Makes an idle hero the city's mayor (the old mayor goes back to idle), or with nil leaves it without one."
  @callback set_mayor(
              player_id :: String.t(),
              city_id :: String.t(),
              hero_id :: String.t() | nil,
              now_ms :: integer
            ) :: :ok | {:error, code :: String.t()}

  @doc """
  Sends a march from one of the player's cities to x, y with hero_id (nil for none) and troops
  (%{"warrior" => 100}), taking the troops, hero, cargo and the trip's food now (Age3.March). opts:
  %{"mission" => "attack" | "scout" | "transport" | "reinforce" | "found", "camp" => seconds the army waits at
  the target before it attacks, "cargo" => resources a transport delivers}; a bare integer is a camp wave.
  Returns when it arrives.
  """
  @callback march(
              player_id :: String.t(),
              city_id :: String.t(),
              x :: integer,
              y :: integer,
              hero_id :: String.t() | nil,
              troops :: map,
              now_ms :: integer,
              opts :: map | non_neg_integer
            ) :: {:ok, ends_at_ms :: integer} | {:error, code :: String.t()}

  @doc """
  A held historic city (city_id) imposes a policy (Age3.Historic.policies/0) on another player's city at x, y.
  Writes a report for both lords.
  """
  @callback impose_policy(
              player_id :: String.t(),
              city_id :: String.t(),
              x :: integer,
              y :: integer,
              policy :: String.t(),
              now_ms :: integer
            ) :: :ok | {:error, String.t()}

  @doc """
  Turns a march that hasn't attacked yet (on its way or camping) around; it takes as long to come back as it has
  been out, at most one trip's time.
  """
  @callback recall(player_id :: String.t(), city_id :: String.t(), task_id :: String.t(), now_ms :: integer) ::
              {:ok, ends_at_ms :: integer} | {:error, code :: String.t()}

  @doc "Ticks or unticks the Embassy's \"let allies garrison this city\" box."
  @callback set_garrison(player_id :: String.t(), city_id :: String.t(), allow :: boolean, now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc "Gives up a valley the city holds; its bonus stops."
  @callback abandon_valley(
              player_id :: String.t(),
              city_id :: String.t(),
              x :: integer,
              y :: integer,
              now_ms :: integer
            ) :: :ok | {:error, code :: String.t()}

  @doc "The player's latest battle reports, newest first, without the battle details."
  @callback reports(player_id :: String.t()) :: [map]

  @doc "One of the player's battle reports with the whole battle (BattleResult), marking it read."
  @callback report(player_id :: String.t(), report_id :: String.t()) ::
              {:ok, map} | {:error, code :: String.t()}

  @doc """
  Builds count of a fortification (trap, abatis, tower, log, trebuchet) at the city's walls, paying now
  (Age3.Forts). The batch joins the end of the walls' queue. Returns when it is done.
  """
  @callback build_forts(
              player_id :: String.t(),
              city_id :: String.t(),
              fort :: String.t(),
              count :: integer,
              now_ms :: integer
            ) :: {:ok, ends_at_ms :: integer} | {:error, code :: String.t()}

  @doc "Stops a fortification batch (running or waiting) and refunds its whole cost."
  @callback cancel_forts(
              player_id :: String.t(),
              city_id :: String.t(),
              task_id :: String.t(),
              now_ms :: integer
            ) ::
              :ok | {:error, code :: String.t()}

  @doc """
  Spends a hero's stat points: add is %{"politics" => n, "attack" => n, "intelligence" => n}. A mayor's new
  Politics changes the city's production at once.
  """
  @callback assign_points(
              player_id :: String.t(),
              city_id :: String.t(),
              hero_id :: String.t(),
              add :: map,
              now_ms :: integer
            ) :: :ok | {:error, code :: String.t()}

  @doc "Buys count of an item from the shop with gold from a city."
  @callback buy_item(
              player_id :: String.t(),
              city_id :: String.t(),
              item :: String.t(),
              count :: integer,
              now_ms :: integer
            ) ::
              :ok | {:error, code :: String.t()}

  @doc "Uses one item in a city: a speed-up on one of its tasks (task_id), or resources into it (task_id nil)."
  @callback use_item(
              player_id :: String.t(),
              city_id :: String.t(),
              item :: String.t(),
              task_id :: String.t() | nil,
              now_ms :: integer
            ) :: :ok | {:error, code :: String.t()}

  @doc "Every routine quest with whether it is done and claimed."
  @callback quests(player_id :: String.t()) :: [map]

  @doc "Claims a done quest's reward into a city (once)."
  @callback claim_quest(
              player_id :: String.t(),
              city_id :: String.t(),
              quest_id :: String.t(),
              now_ms :: integer
            ) ::
              :ok | {:error, code :: String.t()}

  @doc "The top 100 of a leaderboard: \"player\" (prestige), \"hero\" (level) or \"alliance\" (members' prestige)."
  @callback leaderboard(board :: String.t()) :: [map]

  @doc """
  The Marketplace seen from a city: its Marketplace level, the best 5 buy and sell prices per resource (with the
  last trade's price) and the player's open orders.
  """
  @callback market(player_id :: String.t(), city_id :: String.t()) ::
              {:ok, map} | {:error, code :: String.t()}

  @doc """
  Places a buy or sell order (Age3.Market): pays for it, trades at once with what meets it and leaves the rest
  open. Returns {:ok, the trade partners' player ids} or {:error, code}.
  """
  @callback place_order(
              player_id :: String.t(),
              city_id :: String.t(),
              side :: String.t(),
              resource :: String.t(),
              amount :: integer,
              price :: integer,
              now_ms :: integer
            ) :: {:ok, [String.t()]} | {:error, code :: String.t()}

  @doc "Cancels an open order and gives back what it holds."
  @callback cancel_order(
              player_id :: String.t(),
              city_id :: String.t(),
              order_id :: String.t(),
              now_ms :: integer
            ) ::
              :ok | {:error, code :: String.t()}

  @doc """
  Posts a chat line to "world" or "alliance". Returns {:ok, line, to} (to: :all or the alliance id, for
  chat_audience/1) or {:error, code}.
  """
  @callback chat(player_id :: String.t(), channel :: String.t(), text :: String.t(), now_ms :: integer) ::
              {:ok, map, :all | String.t()} | {:error, code :: String.t()}

  @doc "The latest world and alliance chat lines for a player, oldest first."
  @callback chat_history(player_id :: String.t()) :: [map]

  @doc "Who gets a chat line: :all, or the alliance's player ids."
  @callback chat_audience(:all | String.t()) :: :all | [String.t()]

  @doc "Mails a player by name. Returns {:ok, receiver_id} or {:error, code}."
  @callback send_mail(
              player_id :: String.t(),
              to :: String.t(),
              subject :: String.t(),
              body :: String.t(),
              now_ms :: integer
            ) :: {:ok, String.t()} | {:error, code :: String.t()}

  @doc "The player's inbox and sent mail, newest first."
  @callback mailbox(player_id :: String.t()) :: %{inbox: [map], sent: [map]}

  @callback read_mail(player_id :: String.t(), mail_id :: String.t()) :: :ok | {:error, code :: String.t()}
  @callback delete_mail(player_id :: String.t(), mail_id :: String.t()) :: :ok | {:error, code :: String.t()}

  @doc """
  What the Alliance window shows: the player's alliance (members, ranks, diplomacy, applications for officers),
  their invitations and applications, their best Embassy level and the biggest alliances.
  """
  @callback alliance_info(player_id :: String.t()) :: map

  @doc """
  One alliance action (Age3.AllianceStore.action/3): "create" {cityId, name} pays 10,000 gold from a city with
  Embassy Lv2; the others are apply, cancel, invite, accept, reject, leave, kick, setRank, diplomacy, describe
  and disband.
  """
  @callback alliance_action(player_id :: String.t(), action :: String.t(), args :: map, now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc "Stops a construction that hasn't finished and refunds its whole cost."
  @callback cancel_build(
              player_id :: String.t(),
              city_id :: String.t(),
              task_id :: String.t(),
              now_ms :: integer
            ) ::
              :ok | {:error, code :: String.t()}

  @doc """
  A levy (Age3.Levy): takes one resource from the city's people at once, up to the cap, for 20 loyalty. Once every
  15 minutes per city.
  """
  @callback levy(player_id :: String.t(), city_id :: String.t(), kind :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc "Renames one of the player's cities. The name is already checked (Age3.Game.city_name/1)."
  @callback rename_city(player_id :: String.t(), city_id :: String.t(), name :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc """
  Starts taking the building on a slot down one level (Age3.Build.check_demolish/3). Uses the build queue.
  Returns when it will finish (epoch ms).
  """
  @callback demolish(player_id :: String.t(), city_id :: String.t(), slot :: String.t(), now_ms :: integer) ::
              {:ok, ends_at_ms :: integer} | {:error, code :: String.t()}

  @doc """
  Abandons a city for good. Its heroes move to the player's city `move_to` while there's room. Returns how many
  heroes moved.
  """
  @callback abandon_city(
              player_id :: String.t(),
              city_id :: String.t(),
              move_to :: String.t(),
              now_ms :: integer
            ) ::
              {:ok, moved :: integer} | {:error, code :: String.t()}
end

defmodule Age3.Store.Pg do
  # The real store, on Postgres through Ecto.
  @moduledoc false
  @behaviour Age3.Store

  import Ecto.Query

  alias Age3.{
    Accounts,
    Alliance,
    AllianceStore,
    Alliances,
    Build,
    Building,
    Cheats,
    City,
    Combat,
    Data,
    Beacon,
    Economy,
    Forts,
    Market,
    MarketOrder,
    MarketTrade,
    Game,
    Hero,
    Heroes,
    Items,
    Historic,
    Levy,
    Lord,
    Loyalty,
    March,
    Npc,
    NpcState,
    Player,
    Pvp,
    Report,
    Repo,
    Honor,
    Quests,
    Research,
    Task,
    Scout,
    Social,
    Titles,
    Train,
    Valley,
    ValleyHold,
    World
  }

  @impl true
  defdelegate authenticate(name, password), to: Accounts
  @impl true
  defdelegate new_token(player_id), to: Accounts
  @impl true
  defdelegate player_for_token(token), to: Accounts

  @doc "Finds the player with this name, creating them and a starter city the first time. Used by Accounts."
  def find_or_create_player(name) do
    case Repo.get_by(Player, name: name) do
      %Player{id: id} -> {:ok, id}
      nil -> create_player(name)
    end
  end

  # Everything in a transaction: if any step fails, none of it is saved.
  defp create_player(name) do
    Repo.transaction(fn ->
      # if someone else created this name a moment ago, this updates nothing and returns their row
      player =
        Repo.insert!(%Player{name: name},
          on_conflict: [set: [name: name]],
          conflict_target: :name,
          returning: [:id]
        )

      new_city(player.id, name)
      player.id
    end)
  end

  # A new empty city (Town Hall and walls Lv1, starting resources) on a free flat for the player, inside a
  # transaction. For a new player, and for one whose last city was captured.
  defp new_city(player_id, name) do
    case place_city(player_id, name, 200) do
      {:ok, city} ->
        Repo.insert_all(Building, [
          %{city_id: city.id, slot: "townhall", type: "townhall", level: 1},
          %{city_id: city.id, slot: "walls", type: "walls", level: 1}
        ])

        city

      :error ->
        Repo.rollback("no free map spot for #{inspect(name)}")
    end
  end

  # A random free flat (so a city never stands on a generated NPC, valley or made-up town); the unique (x, y)
  # constraint settles any race.
  defp place_city(_player_id, _name, 0), do: :error

  defp place_city(player_id, name, tries) do
    x = :rand.uniform(Game.world_size()) - 1
    y = :rand.uniform(Game.world_size()) - 1

    if Game.historic_city?(x, y) or World.tile_at(x, y).kind != "flat" do
      place_city(player_id, name, tries - 1)
    else
      city = %City{
        player_id: player_id,
        name: name <> "'s Town",
        x: x,
        y: y,
        resources: Game.starter_resources(),
        population: Game.starter_population()
      }

      # on a clash nothing is inserted, and Ecto hands back the struct with no id
      case Repo.insert!(city, on_conflict: :nothing, conflict_target: [:x, :y]) do
        %City{id: nil} -> place_city(player_id, name, tries - 1)
        %City{} = city -> {:ok, city}
      end
    end
  end

  @impl true
  def state(player_id, now_ms) do
    with {:ok, _} <- Ecto.UUID.cast(player_id),
         %Player{} <- Repo.get(Player, player_id) do
      now = to_datetime(now_ms)
      arrivals(Repo.all(from c in City, where: c.player_id == ^player_id, select: c.id), now)
      # read again: an attack that just arrived may have captured one, or given the player a new one
      city_ids = Repo.all(from c in City, where: c.player_id == ^player_id, select: c.id)
      Enum.each(city_ids, &finish_due_in_city(&1, now))
      Enum.each(city_ids, &refresh_stale(&1, now))
      Enum.each(city_ids, &refresh_inn(&1, now_ms))
      # read after finishing tasks, which can raise research levels
      player = Repo.get!(Player, player_id)

      buildings = from(b in Building, order_by: b.slot)
      heroes = from(h in Hero, order_by: [desc: h.level, asc: h.inserted_at])

      cities =
        Repo.all(
          from c in City,
            where: c.player_id == ^player_id,
            order_by: c.id,
            preload: [buildings: ^buildings, heroes: ^heroes]
        )

      tasks = Repo.all(from t in Task, where: t.city_id in ^city_ids, order_by: t.ends_at)

      {:ok, player_json(player), Enum.map(cities, &city_json(&1, tasks, now_ms)),
       Enum.map(tasks, &task_json/1)}
    else
      _ -> {:error, :not_found}
    end
  end

  # Construction. Each command locks the city row first (SELECT ... FOR UPDATE), so two clicks at once can't
  # both pay from the same resources or both start a build; the second waits for the first to commit.

  @impl true
  def build(player_id, city_id, slot, type, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      # finishing a build changes the city's resources and rates, so read it again afterwards
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)

      if Repo.exists?(from t in Task, where: t.city_id == ^city.id and t.kind == "build"),
        do: Repo.rollback("queue_busy")

      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      resources = settled(city, now_ms).resources

      case Build.check(buildings, resources, slot, type, research_of(player_id)) do
        {:ok, plan} ->
          # the Academy can't be upgraded in the middle of a research (a Barracks can, while it trains)
          if plan.type == "academy" and researching?(city.id), do: Repo.rollback("academy_busy")

          save_resources(city, Build.spend(resources, plan.cost), now_ms)
          seconds = Heroes.mayor_seconds(plan.seconds, mayor_of(city.id), :build)

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "build",
            label: "#{Data.building(plan.type)["name"]} → Lv #{plan.level}",
            slot: slot,
            target_type: plan.type,
            target_level: plan.level,
            cost: plan.cost,
            started_at: now,
            ends_at: to_datetime(now_ms + seconds * 1000)
          })

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> case do
      {:ok, task} -> {:ok, to_ms(task.ends_at)}
      {:error, code} -> {:error, code}
    end
  end

  @impl true
  def cancel_build(player_id, city_id, task_id, now_ms),
    do: cancel(player_id, city_id, task_id, "build", now_ms)

  # Research. Same pattern as construction: lock the city, finish what is due, check, pay, insert a task. The
  # player's row is locked after the city's (research levels are shared by all their cities), the same order
  # complete_due takes them in, so two commands can't deadlock.

  @impl true
  def research(player_id, city_id, tech, now_ms) do
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)

      research =
        Repo.one!(from p in Player, where: p.id == ^player_id, lock: "FOR UPDATE", select: p.research)

      if researching?(city.id), do: Repo.rollback("research_busy")

      # one Academy can't research while it is being upgraded, and one tech can't run in two cities at once
      if Repo.exists?(
           from t in Task, where: t.city_id == ^city.id and t.kind == "build" and t.target_type == "academy"
         ),
         do: Repo.rollback("academy_busy")

      if Repo.exists?(
           from t in Task,
             join: c in City,
             on: c.id == t.city_id,
             where: c.player_id == ^player_id and t.kind == "research" and t.target_type == ^tech
         ),
         do: Repo.rollback("already_researching")

      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      resources = settled(city, now_ms).resources

      case Research.check(buildings, research, resources, tech) do
        {:ok, plan} ->
          save_resources(city, Build.spend(resources, plan.cost), now_ms)
          seconds = Heroes.mayor_seconds(plan.seconds, mayor_of(city.id), :research)

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "research",
            label: "#{Data.tech(tech)["name"]} → Lv #{plan.level}",
            target_type: tech,
            target_level: plan.level,
            cost: plan.cost,
            started_at: now,
            ends_at: to_datetime(now_ms + seconds * 1000)
          })

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> case do
      {:ok, task} -> {:ok, to_ms(task.ends_at)}
      {:error, code} -> {:error, code}
    end
  end

  @impl true
  def cancel_research(player_id, city_id, task_id, now_ms),
    do: cancel(player_id, city_id, task_id, "research", now_ms)

  # Training. Same pattern again. Each Barracks works through its own queue of batches (tasks of kind "train"
  # with slot = the Barracks' slot): a new batch starts when the last one in that Barracks ends, so only the
  # first one is running and the rest wait with start times in the future.

  @impl true
  def train(player_id, city_id, slot, troop, count, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)

      # a Barracks keeps training while it is upgraded; its queue size and the troops it unlocks come from the
      # level it has now
      queue = training_queue(city.id, slot)
      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      %{resources: resources, population: %{"idle" => idle}} = settled(city, now_ms)

      case Train.check(buildings, research_of(player_id), resources, idle, slot, troop, count, length(queue)) do
        {:ok, plan} ->
          save_resources(city, Build.spend(resources, plan.cost), now_ms, plan.population)
          starts_ms = Enum.reduce(queue, now_ms, &max(&2, to_ms(&1.ends_at)))
          seconds = Heroes.mayor_seconds(plan.seconds, mayor_of(city.id), :train)

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "train",
            label: "#{count} × #{Data.troop(troop)["name"]}",
            slot: slot,
            target_type: troop,
            target_level: count,
            cost: plan.cost,
            started_at: to_datetime(starts_ms),
            ends_at: to_datetime(starts_ms + seconds * 1000)
          })

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> case do
      {:ok, task} -> {:ok, to_ms(task.ends_at)}
      {:error, code} -> {:error, code}
    end
  end

  # Fortifications (Age3.Forts): batches built at the walls one after another, like a Barracks' queue.
  @impl true
  def build_forts(player_id, city_id, fort, count, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      queue = training_queue(city.id, "walls", "fort")
      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      resources = settled(city, now_ms).resources
      queued = for t <- queue, do: {t.target_type, t.target_level}

      case Forts.check(
             buildings,
             research_of(player_id),
             resources,
             city.forts,
             queued,
             fort,
             count,
             mayor_politics(city.id)
           ) do
        {:ok, plan} ->
          save_resources(city, Build.spend(resources, plan.cost), now_ms)
          starts_ms = Enum.reduce(queue, now_ms, &max(&2, to_ms(&1.ends_at)))

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "fort",
            label: "#{count} × #{Data.fort(fort)["name"]}",
            slot: "walls",
            target_type: fort,
            target_level: count,
            cost: plan.cost,
            started_at: to_datetime(starts_ms),
            ends_at: to_datetime(starts_ms + plan.seconds * 1000)
          })

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> case do
      {:ok, task} -> {:ok, to_ms(task.ends_at)}
      {:error, code} -> {:error, code}
    end
  end

  @impl true
  def cancel_forts(player_id, city_id, task_id, now_ms),
    do: cancel(player_id, city_id, task_id, "fort", now_ms)

  # The mayor's Politics in a city (0 without a mayor): it speeds up construction (x0.995 per point).
  defp mayor_politics(city_id), do: (mayor_of(city_id) || %{politics: 0}).politics

  # A city's mayor, or nil: its Politics, Attack and Intelligence speed up the city's builds, training and
  # research (Heroes.mayor_seconds/3).
  defp mayor_of(city_id), do: Repo.one(from(h in Hero, where: h.city_id == ^city_id and h.status == "mayor"))

  @impl true
  def cancel_train(player_id, city_id, task_id, now_ms),
    do: cancel(player_id, city_id, task_id, "train", now_ms)

  # Stops a task of this kind that hasn't finished and gives its whole cost back (and, for training, the people).
  defp cancel(player_id, city_id, task_id, kind, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")

      # a task that has already finished can't be cancelled, and finishing one changes the city, so read it again
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      task = find_task(city.id, task_id, [kind]) || Repo.rollback("bad_message")
      resources = settled(city, now_ms).resources
      save_resources(city, Build.spend(resources, task.cost, -1), now_ms, -people(task))
      Repo.delete!(task)
      # the batches waiting behind a cancelled one move up
      if kind in ["train", "fort"], do: rechain(city.id, task.slot, now_ms, kind)
    end)
    |> case do
      {:ok, _task} -> :ok
      {:error, code} -> {:error, code}
    end
  end

  @impl true
  def speed_up(player_id, city_id, task_id, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      complete_due(city.id, now)
      task = find_task(city.id, task_id, ["build", "research", "train"]) || Repo.rollback("bad_message")

      # only buildings get the free speedup: no research, training or walls
      if task.kind != "build" or task.slot == "walls", do: Repo.rollback("no_free_speedup")
      if to_ms(task.ends_at) - now_ms > Data.free_speedup_ms(), do: Repo.rollback("too_early")

      # finish it as if it had ended now
      task |> Ecto.Changeset.change(ends_at: now) |> Repo.update!()
      complete_due(city.id, now)
    end)
    |> case do
      {:ok, _done} -> :ok
      {:error, code} -> {:error, code}
    end
  end

  @impl true
  def comfort(player_id, city_id, kind, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      %{resources: resources, population: pop, loyalty: loyalty} = settled(city, now_ms)
      comfort_at = city.comfort_at && to_ms(city.comfort_at)

      case Loyalty.check_comfort(
             kind,
             comfort_at,
             now_ms,
             pop,
             get_in(resources, [kind_resource(kind), "amount"]) || 0
           ) do
        {:ok, c} ->
          {loyalty, grievance} = Loyalty.apply_change(loyalty, city.grievance, c.loyalty, c.grievance)
          resources = resources |> Build.spend(%{c.resource => c.cost}) |> Economy.add_capped(c.gain)
          # Population Raising brings people in: a negative number of people taken
          save_resources(city, resources, now_ms, -c.people)

          Repo.update_all(from(x in City, where: x.id == ^city.id),
            set: [loyalty: loyalty, grievance: grievance, comfort_at: now]
          )

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> ok()
  end

  defp kind_resource(kind) when kind in ["relief", "raise"], do: "food"
  defp kind_resource(_kind), do: "gold"

  # Town Hall actions: levies, renaming, demolishing a building and abandoning a city.

  @impl true
  def levy(player_id, city_id, kind, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      %{resources: resources, population: pop, loyalty: loyalty} = settled(city, now_ms)

      case Levy.check(kind, city.levy_at && to_ms(city.levy_at), now_ms, pop["current"]) do
        {:ok, amount} ->
          save_resources(city, Economy.add_capped(resources, %{kind => amount}), now_ms)

          Repo.update_all(from(c in City, where: c.id == ^city.id),
            set: [loyalty: max(0, loyalty - Levy.loyalty_cost()), levy_at: now]
          )

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> ok()
  end

  @impl true
  def rename_city(player_id, city_id, name, _now_ms) do
    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      Repo.update_all(from(c in City, where: c.id == ^city.id), set: [name: name])
    end)
    |> ok()
  end

  # Demolishing goes through the build queue as a "build" task down to a lower level (0 = gone), so it shares the
  # one-at-a-time queue, shows on the plot like any construction, can be cancelled (nothing was paid, so nothing
  # comes back) and gets the free speed-up at 5 minutes. The refund comes when it finishes.
  @impl true
  def demolish(player_id, city_id, slot, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      complete_due(city.id, now)

      if Repo.exists?(from t in Task, where: t.city_id == ^city.id and t.kind == "build"),
        do: Repo.rollback("queue_busy")

      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)

      case Build.check_demolish(buildings, slot, research_of(player_id)) do
        {:ok, plan} ->
          check_demolish_busy(city, slot, plan)
          name = Data.building(plan.type)["name"]

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "build",
            label: if(plan.level == 0, do: "Demolish #{name}", else: "Demolish #{name} → Lv #{plan.level}"),
            slot: slot,
            target_type: plan.type,
            target_level: plan.level,
            cost: %{},
            data: %{"demolish" => true, "refund" => plan.refund},
            started_at: now,
            ends_at: to_datetime(now_ms + plan.seconds * 1000)
          })

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> case do
      {:ok, task} -> {:ok, to_ms(task.ends_at)}
      {:error, code} -> {:error, code}
    end
  end

  # Buildings that are in use can't go down: an Academy that is researching, a Barracks with troops in training,
  # and a Feasting Hall that would no longer house its heroes.
  defp check_demolish_busy(city, slot, %{type: type, level: level}) do
    case type do
      "academy" ->
        if researching?(city.id), do: Repo.rollback("academy_busy")

      "barracks" ->
        if training_queue(city.id, slot) != [], do: Repo.rollback("barracks_busy")

      "feastinghall" ->
        heroes = Repo.aggregate(from(h in Hero, where: h.city_id == ^city.id), :count)
        if heroes > level, do: Repo.rollback("hall_full")

      _ ->
        :ok
    end
  end

  # Abandoning a city: it is deleted with its buildings, tasks and troops, and its tile is free again. Its heroes
  # move to `move_to` (another of the player's cities) while that Feasting Hall has room, highest level first;
  # the rest are dismissed, and captives are let go. Not the last city, not a historic city, and not while
  # troops are out from it or an attack is on its way to it.
  @impl true
  def abandon_city(player_id, city_id, move_to, now_ms) do
    now = to_datetime(now_ms)

    with {:ok, from_id} <- Ecto.UUID.cast(city_id),
         {:ok, to_id} <- Ecto.UUID.cast(move_to),
         true <- from_id != to_id do
      arrivals([from_id, to_id], now)

      Repo.transaction(fn ->
        # lock both in id order, like an attack does, so two commands can't deadlock
        [first, second] = Enum.sort([from_id, to_id])
        locked = for id <- [first, second], do: lock_city(player_id, id)
        if Enum.any?(locked, &is_nil/1), do: Repo.rollback("bad_message")
        city = Enum.find(locked, &(&1.id == from_id))
        home = Enum.find(locked, &(&1.id == to_id))

        if city.historic_level, do: Repo.rollback("historic_city")

        if Repo.exists?(
             from t in Task,
               where:
                 (t.city_id == ^city.id and t.kind == "march") or
                   (t.target_city_id == ^city.id and t.kind == "march")
           ),
           do: Repo.rollback("troops_out")

        complete_due(home.id, now)
        home_buildings = Repo.all(from b in Building, where: b.city_id == ^home.id)

        room =
          Heroes.capacity(home_buildings) -
            Repo.aggregate(from(h in Hero, where: h.city_id == ^home.id), :count)

        moving =
          Repo.all(
            from h in Hero,
              where: h.city_id == ^city.id and h.status != "captive",
              order_by: [desc: h.level, asc: h.inserted_at],
              select: h.id
          )
          |> Enum.take(max(room, 0))

        Repo.update_all(from(h in Hero, where: h.id in ^moving), set: [city_id: home.id, status: "idle"])
        Repo.delete!(city)
        # the heroes' salaries come off the new city's gold from now on
        resnapshot(Repo.get!(City, home.id), now)
        length(moving)
      end)
      |> case do
        {:ok, moved} -> {:ok, moved}
        {:error, code} -> {:error, code}
      end
    else
      _ -> {:error, "bad_message"}
    end
  end

  @impl true
  def set_gate(player_id, city_id, open, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      Repo.update_all(from(c in City, where: c.id == ^city.id), set: [gate_open: open])
    end)
    |> ok()
  end

  @impl true
  def set_garrison(player_id, city_id, allow, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      Repo.update_all(from(c in City, where: c.id == ^city.id), set: [allow_garrison: allow])
    end)
    |> ok()
  end

  @impl true
  def abandon_valley(player_id, city_id, x, y, now_ms) do
    now = to_datetime(now_ms)
    arrivals([city_id], now)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      complete_due(city.id, now)
      {n, _} = Repo.delete_all(from v in ValleyHold, where: v.city_id == ^city.id and v.x == ^x and v.y == ^y)
      if n == 0, do: Repo.rollback("bad_message")
      # its bonus stops now
      resnapshot(Repo.get!(City, city.id), now)
    end)
    |> ok()
  end

  @impl true
  def set_defender(player_id, city_id, hero_id, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      hero = hero_id && (find_hero(city.id, hero_id) || Repo.rollback("bad_message"))
      if hero && hero.status == "captive", do: Repo.rollback("hero_busy")
      Repo.update_all(from(c in City, where: c.id == ^city.id), set: [defender_hero_id: hero && hero.id])
    end)
    |> ok()
  end

  @impl true
  def persuade(player_id, city_id, hero_id, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      hero = find_hero(city.id, hero_id) || Repo.rollback("bad_message")
      if hero.status != "captive", do: Repo.rollback("bad_message")
      resources = settled(city, now_ms).resources
      fee = Heroes.fee(hero.level)
      if resources["gold"]["amount"] < fee, do: Repo.rollback("not_enough_resources")
      save_resources(city, Build.spend(resources, %{"gold" => fee}), now_ms)
      Repo.update_all(from(h in Hero, where: h.id == ^hero.id), set: [status: "idle"])
      # their salary from now on
      resnapshot(Repo.get!(City, city.id), to_datetime(now_ms))
    end)
    |> ok()
  end

  @impl true
  def lords(player_id) do
    {:ok, player_id} = Ecto.UUID.cast(player_id)

    Repo.all(
      from c in City,
        join: p in Player,
        on: p.id == c.player_id,
        where: c.player_id != ^player_id,
        left_join: b in Building,
        on: b.city_id == c.id and b.slot == "townhall",
        select: %{
          id: c.id,
          name: c.name,
          x: c.x,
          y: c.y,
          level: coalesce(b.level, 1),
          owner: p.name,
          ownerId: p.id,
          alliance: p.alliance,
          allianceId: p.alliance_id,
          historicLevel: c.historic_level
        }
    )
    |> then(fn lords ->
      # how the player's alliance sees each one's: "alliance", "friendly", "hostile" or nil (the map's flags)
      {mine, diplomacy} = AllianceStore.my_diplomacy(player_id)

      Enum.map(lords, fn l ->
        l |> Map.delete(:allianceId) |> Map.put(:relation, Alliances.relation(mine, l.allianceId, diplomacy))
      end)
    end)
  end

  # The Marketplace (Age3.Market). Placing an order pays for it, trades at once with what meets it (crediting the
  # other side's cities) and leaves the rest in the book.
  @impl true
  def market(player_id, city_id) do
    with city when city != nil <- own_city(player_id, city_id) do
      books =
        Map.new(Market.resources(), fn r ->
          {r,
           %{
             buy: book_levels(r, "buy", :desc),
             sell: book_levels(r, "sell", :asc),
             last:
               Repo.one(
                 from(t in MarketTrade,
                   where: t.resource == ^r,
                   order_by: [desc: t.inserted_at],
                   limit: 1,
                   select: t.price
                 )
               )
           }}
        end)

      orders =
        Repo.all(
          from o in MarketOrder,
            join: c in City,
            on: c.id == o.city_id,
            where: o.player_id == ^player_id,
            order_by: o.inserted_at,
            select: %{
              id: o.id,
              cityId: o.city_id,
              city: c.name,
              side: o.side,
              resource: o.resource,
              amount: o.amount,
              price: o.price
            }
        )

      {:ok, %{level: market_level(city.id), books: books, orders: orders}}
    else
      _ -> {:error, "bad_message"}
    end
  end

  defp own_city(player_id, city_id) do
    case Ecto.UUID.cast(city_id) do
      {:ok, id} -> Repo.one(from c in City, where: c.id == ^id and c.player_id == ^player_id)
      :error -> nil
    end
  end

  # the best 5 prices on one side of a resource's book, with how much is there at each
  defp book_levels(resource, side, dir) do
    Repo.all(
      from o in MarketOrder,
        where: o.resource == ^resource and o.side == ^side,
        group_by: o.price,
        order_by: [{^dir, o.price}],
        limit: 5,
        select: %{price: o.price, amount: sum(o.amount)}
    )
    |> Enum.map(&%{&1 | amount: Decimal.to_integer(&1.amount)})
  end

  defp market_level(city_id),
    do:
      Repo.one(
        from(b in Building, where: b.city_id == ^city_id and b.type == "marketplace", select: max(b.level))
      ) || 0

  @impl true
  def place_order(player_id, city_id, side, resource, amount, price, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      open = Repo.aggregate(from(o in MarketOrder, where: o.city_id == ^city.id), :count)

      case Market.check(market_level(city.id), open, side, resource, amount, price) do
        :ok -> :ok
        {:error, code} -> Repo.rollback(code)
      end

      resources = settled(city, now_ms).resources
      cost = if side == "sell", do: %{resource => amount}, else: %{"gold" => Market.gold(amount, price)}
      if Build.affordable(resources, cost) != :ok, do: Repo.rollback("not_enough_resources")

      {other, dir} = if side == "buy", do: {"sell", :asc}, else: {"buy", :desc}

      book =
        Repo.all(
          from o in MarketOrder,
            where: o.resource == ^resource and o.side == ^other and o.player_id != ^player_id,
            order_by: [{^dir, o.price}, asc: o.inserted_at],
            limit: 200,
            lock: "FOR UPDATE"
        )

      {fills, left} = Market.match(side, amount, price, book)

      # what this city gets from the trades made now: resources bought (and, buying below the bid, gold back), or
      # gold for what it sold
      gains =
        Enum.reduce(fills, %{}, fn {o, qty}, acc ->
          trade = Market.gold(qty, o.price)
          Repo.insert!(%MarketTrade{resource: resource, amount: qty, price: o.price, inserted_at: now})

          if o.amount == qty,
            do: Repo.delete!(o),
            else: o |> Ecto.Changeset.change(amount: o.amount - qty) |> Repo.update!()

          if side == "buy" do
            # the seller gets the gold, less the fee; the buyer the goods and the gold it bid over the price
            credit(o.city_id, %{"gold" => trade - Market.fee(trade)}, now)
            acc |> add(resource, qty) |> add("gold", Market.gold(qty, price) - trade)
          else
            credit(o.city_id, %{resource => qty}, now)
            add(acc, "gold", trade - Market.fee(trade))
          end
        end)

      resources = resources |> Build.spend(cost) |> Cheats.add_resources(gains)
      save_resources(city, resources, now_ms)

      if left > 0 do
        Repo.insert!(%MarketOrder{
          city_id: city.id,
          player_id: player_id,
          side: side,
          resource: resource,
          amount: left,
          price: price,
          inserted_at: now
        })
      end

      Repo.all(
        from c in City,
          where: c.id in ^Enum.map(fills, fn {o, _} -> o.city_id end),
          distinct: true,
          select: c.player_id
      )
    end)
  end

  defp add(map, key, n), do: Map.update(map, key, n, &(&1 + n))

  # Adds resources to another city (a trade partner's), settling it first.
  defp credit(city_id, more, now) do
    city = Repo.one!(from c in City, where: c.id == ^city_id, lock: "FOR UPDATE")
    resnapshot(city, now)
    city = Repo.get!(City, city_id)

    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set: [resources: Cheats.add_resources(city.resources, more)]
    )
  end

  @impl true
  def cancel_order(player_id, city_id, order_id, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")

      order =
        with {:ok, id} <- Ecto.UUID.cast(order_id),
             %MarketOrder{city_id: cid} = o when cid == city.id <- Repo.get(MarketOrder, id) do
          o
        else
          _ -> Repo.rollback("bad_message")
        end

      back =
        if order.side == "sell",
          do: %{order.resource => order.amount},
          else: %{"gold" => Market.gold(order.amount, order.price)}

      Repo.delete!(order)
      save_resources(city, Cheats.add_resources(settled(city, now_ms).resources, back), now_ms)
    end)
    |> ok()
  end

  # Items and the shop (Age3.Items), and routine quests (Age3.Quests).
  @impl true
  def buy_item(player_id, city_id, item, count, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      player = Repo.one!(from p in Player, where: p.id == ^player_id, lock: "FOR UPDATE")

      gold =
        case Items.price(item, count) do
          {:ok, g} -> g
          {:error, code} -> Repo.rollback(code)
        end

      resources = settled(city, now_ms).resources
      if Build.affordable(resources, %{"gold" => gold}) != :ok, do: Repo.rollback("not_enough_resources")
      save_resources(city, Build.spend(resources, %{"gold" => gold}), now_ms)
      player |> Ecto.Changeset.change(items: Items.give(player.items, %{item => count})) |> Repo.update!()
    end)
    |> ok()
  end

  @impl true
  def use_item(player_id, city_id, item, task_id, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      player = Repo.one!(from p in Player, where: p.id == ^player_id, lock: "FOR UPDATE")
      complete_due(city.id, now)

      left =
        case Items.take(player.items, item) do
          {:ok, left} -> left
          {:error, code} -> Repo.rollback(code)
        end

      case Items.resources(item) do
        nil ->
          task =
            (task_id && find_task(city.id, task_id, ["build", "research", "train", "fort"])) ||
              Repo.rollback("bad_message")

          # a Barracks or the walls work through their queue in order: only the batch running now can be sped up
          if task.kind in ["train", "fort"] and to_ms(task.started_at) > now_ms,
            do: Repo.rollback("not_started")

          ends =
            case Items.speed_up(item, task.kind, to_ms(task.ends_at), now_ms) do
              {:ok, ms} -> ms
              {:error, code} -> Repo.rollback(code)
            end

          task |> Ecto.Changeset.change(ends_at: to_datetime(ends)) |> Repo.update!()
          if task.kind in ["train", "fort"], do: rechain(city.id, task.slot, now_ms, task.kind)
          complete_due(city.id, now)

        more ->
          city = Repo.get!(City, city.id)
          save_resources(city, Cheats.add_resources(settled(city, now_ms).resources, more), now_ms)
      end

      player |> Ecto.Changeset.change(items: left) |> Repo.update!()
    end)
    |> ok()
  end

  @impl true
  def quests(player_id), do: Quests.status(quest_facts(player_id), Repo.get!(Player, player_id).quests)

  @impl true
  def claim_quest(player_id, city_id, quest_id, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      player = Repo.one!(from p in Player, where: p.id == ^player_id, lock: "FOR UPDATE")
      quest = Quests.quest(quest_id) || Repo.rollback("bad_message")
      if quest_id in player.quests, do: Repo.rollback("already_claimed")
      if not Quests.done?(quest["goal"], quest_facts(player_id)), do: Repo.rollback("requirement_not_met")

      reward = quest["reward"] || %{}
      resources = Cheats.add_resources(settled(city, now_ms).resources, reward["resources"] || %{})
      save_resources(city, resources, now_ms)

      player
      |> Ecto.Changeset.change(
        quests: [quest_id | player.quests],
        items: Items.give(player.items, reward["items"])
      )
      |> Repo.update!()
    end)
    |> ok()
  end

  # What the quests' goals look at, over all the player's cities.
  defp quest_facts(player_id) do
    player = Repo.get!(Player, player_id)
    cities = Repo.all(from c in City, where: c.player_id == ^player_id, preload: [:buildings, :heroes])
    buildings = Enum.flat_map(cities, & &1.buildings)

    %{
      buildings:
        Enum.reduce(buildings, %{}, fn b, acc -> Map.update(acc, b.type, b.level, &max(&1, b.level)) end),
      research: player.research,
      troops:
        Enum.reduce(cities, %{}, fn c, acc -> Map.merge(acc, c.troops || %{}, fn _k, a, b -> a + b end) end),
      town_hall: Enum.max([0 | for(b <- buildings, b.type == "townhall", do: b.level)]),
      population: Enum.max([0 | for(c <- cities, do: c.population["max"] || 0)]),
      prestige: player.prestige,
      cities: length(cities),
      valleys: Repo.aggregate(from(v in ValleyHold, where: v.city_id in ^Enum.map(cities, & &1.id)), :count),
      heroes: Enum.count(Enum.flat_map(cities, & &1.heroes), &(&1.status != "captive")),
      mayor: Enum.any?(Enum.flat_map(cities, & &1.heroes), &(&1.status == "mayor")),
      alliance: player.alliance_id != nil,
      title: player.title
    }
  end

  # Leaderboards: the top 100 players (prestige), heroes (level, then exp) and alliances (members' prestige).
  @impl true
  def leaderboard("player") do
    Repo.all(
      from p in Player,
        left_join: c in City,
        on: c.player_id == p.id,
        group_by: p.id,
        order_by: [desc: p.prestige, asc: p.name],
        limit: 100,
        select: %{
          name: p.name,
          alliance: p.alliance,
          prestige: p.prestige,
          honor: p.honor,
          cities: count(c.id)
        }
    )
    |> ranked()
  end

  def leaderboard("hero") do
    Repo.all(
      from h in Hero,
        join: c in City,
        on: c.id == h.city_id,
        join: p in Player,
        on: p.id == c.player_id,
        where: h.status != "captive",
        order_by: [desc: h.level, desc: h.exp, asc: h.name],
        limit: 100,
        select: %{
          name: h.name,
          lord: p.name,
          level: h.level,
          attack: h.attack,
          politics: h.politics,
          intelligence: h.intelligence
        }
    )
    |> ranked()
  end

  def leaderboard("alliance") do
    Repo.all(
      from a in Alliance,
        join: p in Player,
        on: p.alliance_id == a.id,
        group_by: a.id,
        order_by: [desc: sum(p.prestige), asc: a.name],
        limit: 100,
        select: %{name: a.name, members: count(p.id), prestige: sum(p.prestige)}
    )
    |> ranked()
  end

  def leaderboard(_board), do: []

  defp ranked(rows), do: rows |> Enum.with_index(1) |> Enum.map(fn {r, i} -> Map.put(r, :rank, i) end)

  # Chat and mail (Age3.Social).
  @impl true
  def chat(player_id, channel, text, now_ms), do: Social.chat(player_id, channel, text, now_ms)
  @impl true
  def chat_history(player_id), do: Social.history(player_id)
  @impl true
  def chat_audience(:all), do: :all
  def chat_audience(alliance_id), do: Social.alliance_members(alliance_id)
  @impl true
  def send_mail(player_id, to, subject, body, now_ms),
    do: Social.send_mail(player_id, to, subject, body, now_ms)

  @impl true
  def mailbox(player_id), do: Social.mailbox(player_id)
  @impl true
  def read_mail(player_id, mail_id), do: Social.read_mail(player_id, mail_id)
  @impl true
  def delete_mail(player_id, mail_id), do: Social.delete_mail(player_id, mail_id)

  # Alliances (Age3.AllianceStore). Founding one pays 10,000 gold from a city with Embassy Lv2.
  @impl true
  def alliance_info(player_id), do: AllianceStore.info(player_id)

  @impl true
  def alliance_action(player_id, "create", %{"cityId" => city_id, "name" => name}, now_ms)
      when is_binary(city_id) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      player = Repo.one!(from p in Player, where: p.id == ^player_id, lock: "FOR UPDATE")

      embassy =
        Repo.one(
          from(b in Building, where: b.city_id == ^city.id and b.type == "embassy", select: max(b.level))
        ) ||
          0

      if embassy < 2, do: Repo.rollback("requirement_not_met")
      resources = settled(city, now_ms).resources
      cost = %{"gold" => Alliances.create_gold()}

      case Build.affordable(resources, cost) do
        :ok -> save_resources(city, Build.spend(resources, cost), now_ms)
        {:error, code} -> Repo.rollback(code)
      end

      AllianceStore.create(player, name)
    end)
    |> ok()
  end

  def alliance_action(player_id, action, args, _now_ms) when action != "create",
    do: AllianceStore.action(player_id, action, args)

  def alliance_action(_player_id, _action, _args, _now_ms), do: {:error, "bad_message"}

  @impl true
  def set_tax(player_id, city_id, tax_rate, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      complete_due(city.id, now)
      resnapshot(Repo.get!(City, city.id), now, tax_rate: tax_rate)
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, code} -> {:error, code}
    end
  end

  # Heroes. Same pattern: lock the city, settle, check with Age3.Heroes, write. Hiring and dismissing change the
  # heroes' salaries, so the city gets a new snapshot with the new gold rate (resnapshot).

  @impl true
  def hire(player_id, city_id, offer_id, now_ms) do
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      heroes = Repo.all(from h in Hero, where: h.city_id == ^city.id)
      {inn, _changed} = Heroes.current_inn(city.inn, Heroes.offer_count(buildings), now_ms)
      resources = settled(city, now_ms).resources

      case Heroes.check_hire(buildings, heroes, inn, offer_id, resources["gold"]["amount"]) do
        {:ok, offer} ->
          Repo.insert!(%Hero{
            city_id: city.id,
            name: offer["name"],
            level: offer["level"],
            politics: offer["politics"],
            attack: offer["attack"],
            intelligence: offer["intelligence"]
          })

          save_resources(city, Build.spend(resources, %{"gold" => Heroes.fee(offer["level"])}), now_ms)

          Repo.update_all(from(c in City, where: c.id == ^city.id),
            set: [inn: Heroes.remove_offer(inn, offer_id)]
          )

          # the new salary: settled to now above, so the snapshot is already at now_ms
          resnapshot(Repo.get!(City, city.id), now)

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> ok()
  end

  @impl true
  def reroll_inn(player_id, city_id, now_ms) do
    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, to_datetime(now_ms)) == [], do: city, else: Repo.get!(City, city.id)
      level = Repo.one(from b in Building, where: b.city_id == ^city.id and b.type == "inn", select: b.level)
      if is_nil(level), do: Repo.rollback("no_inn")
      {inn, _changed} = Heroes.current_inn(city.inn, level, now_ms)
      Repo.update_all(from(c in City, where: c.id == ^city.id), set: [inn: Heroes.reroll(inn, level)])
    end)
    |> ok()
  end

  @impl true
  def dismiss(player_id, city_id, hero_id, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      hero = find_hero(city.id, hero_id) || Repo.rollback("bad_message")
      # a captive is released this way
      if hero.status not in ["idle", "captive"], do: Repo.rollback("hero_busy")
      Repo.delete!(hero)
      resnapshot(city, to_datetime(now_ms))
    end)
    |> ok()
  end

  @impl true
  def set_mayor(player_id, city_id, hero_id, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      hero = hero_id && (find_hero(city.id, hero_id) || Repo.rollback("bad_message"))
      if hero && hero.status not in ["idle", "mayor"], do: Repo.rollback("hero_busy")

      Repo.update_all(from(h in Hero, where: h.city_id == ^city.id and h.status == "mayor"),
        set: [status: "idle"]
      )

      if hero, do: Repo.update_all(from(h in Hero, where: h.id == ^hero.id), set: [status: "mayor"])
      # the mayor's Politics adds to production
      resnapshot(city, to_datetime(now_ms))
    end)
    |> ok()
  end

  @impl true
  def assign_points(player_id, city_id, hero_id, add, now_ms) do
    arrivals([city_id], to_datetime(now_ms))

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      hero = find_hero(city.id, hero_id) || Repo.rollback("bad_message")
      if hero.status == "captive", do: Repo.rollback("hero_busy")

      case Heroes.assign(hero, add) do
        {:ok, changes} -> Repo.update_all(from(h in Hero, where: h.id == ^hero.id), set: changes)
        {:error, code} -> Repo.rollback(code)
      end

      if hero.status == "mayor", do: resnapshot(city, to_datetime(now_ms))
    end)
    |> ok()
  end

  defp ok({:ok, _}), do: :ok
  defp ok({:error, code}), do: {:error, code}

  defp find_hero(city_id, hero_id) do
    case Ecto.UUID.cast(hero_id) do
      {:ok, id} -> Repo.one(from h in Hero, where: h.id == ^id and h.city_id == ^city_id)
      :error -> nil
    end
  end

  # captives aren't paid
  defp salary_of(city_id),
    do:
      Heroes.salaries(
        Repo.all(
          from h in Hero, where: h.city_id == ^city_id and h.status != "captive", select: %{level: h.level}
        )
      )

  # Rolls new Inn offers when the old ones have run out (or the Inn's level changed), under the city's lock so two
  # reads at once can't each roll a different set.
  defp refresh_inn(city_id, now_ms) do
    stale? = fn city ->
      level = Repo.one(from b in Building, where: b.city_id == ^city.id and b.type == "inn", select: b.level)
      Heroes.current_inn(city.inn, level || 0, now_ms)
    end

    case stale?.(Repo.get!(City, city_id)) do
      {_inn, false} ->
        :ok

      _ ->
        Repo.transaction(fn ->
          city = Repo.one(from c in City, where: c.id == ^city_id, lock: "FOR UPDATE")
          {inn, changed?} = stale?.(city)
          if changed?, do: Repo.update_all(from(c in City, where: c.id == ^city_id), set: [inn: inn])
        end)
    end
  end

  # Marches. Sending takes the troops, the hero and the trip's food from the city now; the battle is fought when
  # the march task ends (complete_due), which then starts a second task for the way back. See Age3.March.

  # A stationed reinforcement never ends by itself: its lord recalls it.
  @never ~U[9999-01-01 00:00:00.000000Z]

  @impl true
  def march(player_id, city_id, x, y, hero_id, troops, now_ms, opts \\ %{})

  def march(player_id, city_id, x, y, hero_id, troops, now_ms, camp) when is_integer(camp),
    do: march(player_id, city_id, x, y, hero_id, troops, now_ms, %{"camp" => camp})

  def march(player_id, city_id, x, y, hero_id, troops, now_ms, opts) do
    now = to_datetime(now_ms)
    arrivals([city_id], now)
    mission = opts["mission"] || "attack"

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      player = Repo.get!(Player, player_id)
      research = Research.in_city(player.research, buildings)
      hero = hero_id && (find_hero(city.id, hero_id) || Repo.rollback("no_hero"))
      resources = settled(city, now_ms).resources
      food = resources["food"]["amount"]
      stock = Map.new(resources, fn {k, v} -> {k, v["amount"]} end)

      target = March.target(mission, city_at(x, y), World.tile_at(x, y), player_id)
      mission_allowed(mission, target, city, player, x, y)
      marches = Repo.aggregate(from(t in Task, where: t.city_id == ^city.id and t.kind == "march"), :count)
      rally = Historic.rally_multiplier(city.historic_level)
      relief = March.relief(Build.level_of(buildings, "reliefstation"))

      opts = [
        mission: mission,
        rally_multiplier: rally,
        marches: marches,
        camp: opts["camp"] || 0,
        cargo: opts["cargo"],
        stock: stock,
        relief: relief
      ]

      case March.check(
             buildings,
             research,
             city.troops,
             hero,
             {city.x, city.y},
             {x, y},
             food,
             troops,
             target,
             opts
           ) do
        {:ok, plan} ->
          seconds = if player.instant_march, do: 1, else: plan.seconds
          spent = Map.update(plan.cargo, "food", plan.food, &(&1 + plan.food))
          save_resources(city, Build.spend(resources, spent), now_ms)

          Repo.update_all(from(c in City, where: c.id == ^city.id),
            set: [troops: March.take(city.troops, plan.troops)]
          )

          if hero, do: Repo.update_all(from(h in Hero, where: h.id == ^hero.id), set: [status: "marching"])
          # fewer troops at home eat less food
          resnapshot(Repo.get!(City, city.id), now)

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "march",
            label: march_label(mission, target, x, y),
            target_type: mission,
            target_level: plan.level || elem(target, 1).level,
            target_city_id: with({:city, c} <- target, do: c.id, else: (_ -> nil)),
            cost: spent,
            data: %{
              "phase" => "out",
              "mission" => mission,
              "x" => x,
              "y" => y,
              "heroId" => hero && hero.id,
              "heroName" => hero && hero.name,
              "troops" => plan.troops,
              "cargo" => plan.cargo,
              "seconds" => seconds,
              "camp" => plan.camp,
              "target" => Atom.to_string(elem(target, 0))
            },
            started_at: now,
            # the camp wave: it waits at the target before it attacks
            ends_at: to_datetime(now_ms + (seconds + plan.camp) * 1000)
          })

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> case do
      {:ok, task} ->
        # the target's Beacon Tower sees it coming (without one, nothing is known until it hits): refresh the
        # defender's open games
        if task.target_city_id && beacon_at(task.target_city_id) > 0,
          do:
            tell(
              Repo.one(from c in City, where: c.id == ^task.target_city_id, select: c.player_id),
              "incoming"
            )

        {:ok, to_ms(task.ends_at)}

      {:error, code} ->
        {:error, code}
    end
  end

  defp beacon_at(city_id),
    do:
      Repo.one(
        from b in Building, where: b.city_id == ^city_id and b.type == "beacontower", select: max(b.level)
      ) || 0

  # Checks a mission needs the database for, inside the march's transaction: valleys (the city's cap, not your
  # own), founding (the title's city cap, counting Found City marches already out) and reinforcing someone
  # else's city (an ally whose Embassy takes garrisons and has room).
  defp mission_allowed("attack", {:valley, _level}, city, _player, x, y) do
    case Repo.one(from v in ValleyHold, where: v.x == ^x and v.y == ^y, preload: :city) do
      %ValleyHold{city: %City{player_id: owner}} when owner == city.player_id ->
        Repo.rollback("own_valley")

      # alliance members' and friendly alliances' valleys are safe
      %ValleyHold{city: %City{player_id: owner}} ->
        if AllianceStore.relation(city.player_id, owner) in ["alliance", "friendly"],
          do: Repo.rollback("friendly")

      _ ->
        :ok
    end

    town_hall =
      Repo.one(from(b in Building, where: b.city_id == ^city.id and b.slot == "townhall", select: b.level))

    if valley_count(city.id) >= Valley.cap(town_hall || 0), do: Repo.rollback("valley_cap")
  end

  defp mission_allowed("found", _target, _city, player, _x, _y) do
    cities = Repo.aggregate(from(c in City, where: c.player_id == ^player.id), :count)

    founding =
      Repo.aggregate(
        from(t in Task,
          join: c in City,
          on: c.id == t.city_id,
          where: c.player_id == ^player.id and t.kind == "march" and t.target_type == "found"
        ),
        :count
      )

    if cities + founding >= Titles.city_cap(player.title), do: Repo.rollback("city_cap")
  end

  defp mission_allowed("reinforce", {:city, %City{player_id: owner} = host}, city, _player, _x, _y)
       when owner != city.player_id do
    unless can_garrison?(host, city.player_id), do: Repo.rollback("not_allied")
  end

  # no attacking or scouting your own alliance's members, or alliances yours calls friendly
  defp mission_allowed(mission, {:city, %City{player_id: owner}}, city, _player, _x, _y)
       when mission in ["attack", "scout"] do
    if AllianceStore.relation(city.player_id, owner) in ["alliance", "friendly"],
      do: Repo.rollback("friendly")
  end

  defp mission_allowed(_mission, _target, _city, _player, _x, _y), do: :ok

  # Can player_id station troops in host (another player's city)? Only an ally's, and only while its Embassy
  # takes garrisons and has room for one more (a wave per Embassy level).
  defp can_garrison?(host, player_id) do
    embassy =
      Repo.one(
        from(b in Building, where: b.city_id == ^host.id and b.type == "embassy", select: max(b.level))
      ) || 0

    stationed =
      Repo.aggregate(
        from(t in Task,
          where: t.target_city_id == ^host.id and t.kind == "march" and t.target_type == "reinforce"
        ),
        :count
      )

    host.allow_garrison and allies?(host.player_id, player_id) and stationed < embassy
  end

  defp valley_count(city_id), do: Repo.aggregate(from(v in ValleyHold, where: v.city_id == ^city_id), :count)

  defp march_label("attack", target, x, y), do: attack_label(target, x, y)
  defp march_label("scout", {:city, c}, x, y), do: "Scouting #{c.name} (#{x},#{y})"
  defp march_label("scout", _target, x, y), do: "Scouting (#{x},#{y})"
  defp march_label("transport", {:city, c}, x, y), do: "Transport to #{c.name} (#{x},#{y})"
  defp march_label("reinforce", {:city, c}, x, y), do: "Reinforcing #{c.name} (#{x},#{y})"
  defp march_label("found", _target, x, y), do: "Founding a city at (#{x},#{y})"

  defp attack_label({:city, c}, x, y), do: "Attack on #{c.name} (#{x},#{y})"
  defp attack_label({:npc, level}, x, y), do: "Attack on Lv#{level} NPC (#{x},#{y})"
  defp attack_label({:lord, _level}, x, y), do: "Attack on #{Lord.name(x, y)} (#{x},#{y})"
  defp attack_label({:historic, _level}, x, y), do: "Attack on #{Historic.name(x, y)} (#{x},#{y})"
  defp attack_label({:valley, level}, x, y), do: "Attack on Lv#{level} valley (#{x},#{y})"

  # Policies: a held historic city takes from another lord's city in its draft area (Age3.Historic). Both cities
  # are locked in id order (like an arriving attack), settled to now, and both lords get a report.

  @impl true
  def impose_policy(player_id, city_id, x, y, policy, now_ms) do
    now = to_datetime(now_ms)
    target = city_at(x, y)
    with %City{} <- target, {:ok, _} <- Ecto.UUID.cast(city_id), do: arrivals([city_id, target.id], now)

    Repo.transaction(fn ->
      target = city_at(x, y) || Repo.rollback("bad_target")
      {:ok, src_id} = Ecto.UUID.cast(city_id)
      ids = Enum.uniq(Enum.sort([src_id, target.id]))
      Repo.all(from c in City, where: c.id in ^ids, order_by: c.id, lock: "FOR UPDATE", select: c.id)
      src = Repo.get(City, src_id)
      player = Repo.get!(Player, player_id)

      cond do
        src == nil or src.player_id != player_id ->
          Repo.rollback("bad_message")

        policy not in Historic.policies() ->
          Repo.rollback("bad_message")

        src.historic_level == nil ->
          Repo.rollback("not_historic")

        target.player_id == player_id ->
          Repo.rollback("own_city")

        not Titles.at_least?(:title, player.title, Historic.policy_title()) ->
          Repo.rollback("title_too_low")

        not Historic.in_range?(src.historic_level, {src.x, src.y}, {target.x, target.y}) ->
          Repo.rollback("out_of_range")

        Historic.policies_left(src.historic_level, src.policies_used, src.policies_day, now_ms) <= 0 ->
          Repo.rollback("no_policies_left")

        true ->
          :ok
      end

      complete_due(src.id, now)
      complete_due(target.id, now)
      src = Repo.get!(City, src.id)
      target = Repo.get!(City, target.id)
      %{resources: resources, population: pop} = settled(target, now_ms)
      amounts = Map.new(resources, fn {k, v} -> {k, v["amount"]} end)
      taken = Historic.take(policy, amounts, pop["idle"], target.troops)
      save_resources(target, Build.spend(resources, taken["resources"]), now_ms, taken["people"])
      gone = taken["troops"]

      Repo.update_all(from(c in City, where: c.id == ^target.id),
        set: [troops: Map.new(target.troops, fn {t, n} -> {t, n - Map.get(gone, t, 0)} end)]
      )

      # gold, food and people go to the historic city; drafted troops join its army (disarmed ones are gone)
      src_resources = Cheats.add_resources(settled(src, now_ms).resources, taken["resources"])
      save_resources(src, src_resources, now_ms, -taken["people"])

      troops =
        if policy == "draft",
          do: Enum.reduce(gone, src.troops, fn {t, n}, acc -> Train.add(acc, t, n) end),
          else: src.troops

      used =
        Historic.policies_a_day(src.historic_level) -
          Historic.policies_left(src.historic_level, src.policies_used, src.policies_day, now_ms)

      Repo.update_all(from(c in City, where: c.id == ^src.id),
        set: [troops: troops, policies_used: used + 1, policies_day: Historic.day(now_ms)]
      )

      resnapshot(Repo.get!(City, src.id), now)
      resnapshot(Repo.get!(City, target.id), now)

      name =
        Map.new(
          Repo.all(from p in Player, where: p.id in ^[player_id, target.player_id], select: {p.id, p.name})
        )

      label = policy_label(policy)
      info = %{"policy" => policy, "from" => src.name, "to" => target.name, "taken" => taken}

      for {owner, city, title, side} <- [
            {player_id, src, "#{label} on #{target.name} (#{target.x},#{target.y})", "policy"},
            {target.player_id, target, "#{src.name} (#{name[player_id]}) imposed #{label} on #{target.name}",
             "policied"}
          ] do
        Repo.insert!(%Report{
          player_id: owner,
          city_id: city.id,
          title: title,
          x: target.x,
          y: target.y,
          won: side == "policy",
          loot: taken["resources"],
          side: side,
          policy: info,
          fought_at: now
        })
      end

      target.player_id
    end)
    |> case do
      {:ok, other} ->
        tell(other, "attacked")
        :ok

      {:error, code} ->
        {:error, code}
    end
  end

  defp policy_label("tax"), do: "Tax Imposition"
  defp policy_label("food"), do: "Food Levy"
  defp policy_label("population"), do: "Population Redeployment"
  defp policy_label("draft"), do: "Draft"
  defp policy_label("disarm"), do: "Disarmament"

  # The player city standing at x, y (wrapped onto the map), or nil.
  defp city_at(x, y) do
    size = Game.world_size()
    {x, y} = {Integer.mod(x, size), Integer.mod(y, size)}
    Repo.one(from c in City, where: c.x == ^x and c.y == ^y)
  end

  @impl true
  def recall(player_id, city_id, task_id, now_ms) do
    arrivals([city_id], to_datetime(now_ms))
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      complete_due(city.id, now)
      task = find_task(city.id, task_id, ["march"]) || Repo.rollback("bad_message")
      if task.data["phase"] not in ["out", "stationed"], do: Repo.rollback("already_returning")
      # a march camping at its target is a whole trip from home, not further; troops stationed in an ally's
      # city come back the whole way
      back_ms =
        if task.data["phase"] == "stationed",
          do: task.data["seconds"] * 1000,
          else: max(1000, min(now_ms - to_ms(task.started_at), task.data["seconds"] * 1000))

      task
      |> Ecto.Changeset.change(
        label: "Returning from (#{task.data["x"]},#{task.data["y"]})",
        data: Map.merge(task.data, %{"phase" => "back", "loot" => task.data["cargo"] || %{}}),
        target_city_id: nil,
        started_at: now,
        ends_at: to_datetime(now_ms + back_ms)
      )
      |> Repo.update!()
    end)
    |> case do
      {:ok, task} -> {:ok, to_ms(task.ends_at)}
      {:error, code} -> {:error, code}
    end
  end

  # How many reports the Reports window lists.
  @reports 30

  @impl true
  def reports(player_id) do
    case Ecto.UUID.cast(player_id) do
      {:ok, id} ->
        Repo.all(
          from r in Report,
            where: r.player_id == ^id,
            order_by: [desc: r.fought_at],
            limit: @reports,
            select:
              struct(r, [
                :id,
                :city_id,
                :title,
                :x,
                :y,
                :won,
                :loot,
                :medals,
                :side,
                :loyalty,
                :policy,
                :scout,
                :kind,
                :hero,
                :read,
                :fought_at
              ])
        )
        |> Enum.map(&report_json/1)

      :error ->
        []
    end
  end

  @impl true
  def report(player_id, report_id) do
    with {:ok, id} <- Ecto.UUID.cast(report_id),
         %Report{} = r <- Repo.one(from r in Report, where: r.id == ^id and r.player_id == ^player_id) do
      unless r.read, do: Repo.update_all(from(x in Report, where: x.id == ^r.id), set: [read: true])
      {:ok, r |> report_json() |> Map.merge(%{read: true, result: r.result})}
    else
      _ -> {:error, "bad_message"}
    end
  end

  defp unread_reports(player_id),
    do: Repo.aggregate(from(r in Report, where: r.player_id == ^player_id and not r.read), :count)

  # Promotions: one step up the rank or title ladder (Age3.Titles), paid with gold from city_id (whose Town Hall
  # counts for ranks) and the player's medals. Locks the city, then the player, like research.

  @impl true
  def promote(player_id, city_id, ladder, now_ms) do
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      player = Repo.one!(from p in Player, where: p.id == ^player_id, lock: "FOR UPDATE")

      town_hall =
        Repo.one(from b in Building, where: b.city_id == ^city.id and b.slot == "townhall", select: b.level)

      resources = settled(city, now_ms).resources

      case Titles.check(ladder, player, resources["gold"]["amount"], town_hall || 0) do
        {:ok, step} ->
          save_resources(city, Build.spend(resources, %{"gold" => step["gold"]}), now_ms)
          field = if ladder == :rank, do: :military_rank, else: :title

          Repo.update_all(from(p in Player, where: p.id == ^player_id),
            set: [{field, step["id"]}, {:medals, Titles.spend(player.medals, step)}],
            inc: [prestige: step["prestigeAward"]]
          )

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> ok()
  end

  # Cheats (testing commands). Locks the target cities in id order and then the player, like research does, so
  # they can't deadlock with other commands. Anything already due finishes first.

  @impl true
  def cheat(player_id, target, action, args, now_ms) do
    now = to_datetime(now_ms)
    with {:city, city_id} <- target, do: arrivals([city_id], now)

    Repo.transaction(fn ->
      {target_id, city_ids} = cheat_target(player_id, target) || Repo.rollback(not_found(target))

      Repo.all(from c in City, where: c.id in ^city_ids, order_by: c.id, lock: "FOR UPDATE", select: c.id)
      Enum.each(city_ids, &complete_due(&1, now))

      cond do
        action == "instantMarch" ->
          Repo.update_all(from(p in Player, where: p.id == ^target_id), set: [instant_march: args.on])

        action == "setHero" ->
          cheat_hero(city_ids, args, now)

        action == "addMedals" ->
          add_medals(target_id, args.medals)

        action == "setHistoric" ->
          cheat_historic(args, now_ms)

        action == "setTitle" ->
          Repo.update_all(from(p in Player, where: p.id == ^target_id), set: args.changes)

        Cheats.research?(action) ->
          research =
            Repo.one!(from p in Player, where: p.id == ^target_id, lock: "FOR UPDATE", select: p.research)

          research =
            case action do
              "setResearch" -> Cheats.set_research(research, args.tech, args.level)
              "researchAll" -> Cheats.all_research(args.level)
            end

          Repo.update_all(from(p in Player, where: p.id == ^target_id), set: [research: research])
          # production, storage and build times change in every city
          Enum.each(city_ids, &resnapshot(Repo.get!(City, &1), now))

        true ->
          Enum.each(city_ids, fn id ->
            case cheat_city(Repo.get!(City, id), action, args, now_ms) do
              {:error, code} -> Repo.rollback(code)
              _done -> :ok
            end
          end)
      end

      target_id
    end)
  end

  # setHistoric: a free historic city's loyalty and/or an empty garrison, as of now.
  defp cheat_historic(%{x: x, y: y} = args, now_ms) do
    if city_at(x, y), do: Repo.rollback("bad_target")
    level = Game.historic_level(x, y)
    full = Historic.full(x, y, level, Historic.day(now_ms))
    {npc, row} = lock_npc(x, y, level, full, now_ms, Historic.regen_seconds(), true)
    zero = fn m -> Map.new(m, fn {k, _} -> {k, 0} end) end

    Repo.update_all(from(n in NpcState, where: n.x == ^x and n.y == ^y),
      set: [
        troops: if(args.empty, do: zero.(npc["troops"]), else: npc["troops"]),
        forts: if(args.empty, do: zero.(npc["forts"]), else: npc["forts"]),
        resources: npc["resources"],
        loyalty: args.loyalty || Historic.loyalty(row.loyalty, to_ms(row.updated_at), now_ms),
        updated_at: to_datetime(now_ms)
      ]
    )
  end

  # setHero: one hero in the target's cities, then its city's gold rate again (the salary follows the level).
  defp cheat_hero(city_ids, %{hero_id: hero_id, changes: changes}, now) do
    with {:ok, id} <- Ecto.UUID.cast(hero_id),
         %Hero{city_id: city_id} <- Repo.one(from h in Hero, where: h.id == ^id and h.city_id in ^city_ids) do
      Repo.update_all(from(h in Hero, where: h.id == ^id), set: changes)
      resnapshot(Repo.get!(City, city_id), now)
    else
      _ -> Repo.rollback("hero_not_found")
    end
  end

  # {target player's id, the city ids to change}, or nil when there is no such city or player.
  defp cheat_target(player_id, {:city, city_id}) do
    with {:ok, id} <- Ecto.UUID.cast(city_id),
         true <- Repo.exists?(from c in City, where: c.id == ^id and c.player_id == ^player_id) do
      {player_id, [id]}
    else
      _ -> nil
    end
  end

  defp cheat_target(_player_id, {:player, name}) do
    case Repo.get_by(Player, name: name) do
      %Player{id: id} ->
        {id, Repo.all(from c in City, where: c.player_id == ^id, order_by: c.id, select: c.id)}

      nil ->
        nil
    end
  end

  defp not_found({:player, _}), do: "player_not_found"
  defp not_found(_target), do: "bad_message"

  # One city's cheat, inside the transaction holding its lock. {:error, code} undoes the whole cheat.
  defp cheat_city(city, "addResources", %{amounts: amounts}, now_ms) do
    resources = settled(city, now_ms).resources
    save_resources(city, Cheats.add_resources(resources, amounts), now_ms)
  end

  defp cheat_city(city, "fillResources", _args, now_ms) do
    resources = settled(city, now_ms).resources
    save_resources(city, Cheats.fill_resources(resources), now_ms)
  end

  # troops eat food, so the rates change too
  defp cheat_city(city, "addTroops", %{troops: troops}, now_ms) do
    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set: [troops: Cheats.add_troops(city.troops, troops)]
    )

    resnapshot(city, to_datetime(now_ms))
  end

  # the population can't go above the limit (it would be cut back at the next change); cottages raise the limit
  defp cheat_city(city, "setPopulation", %{amount: amount}, now_ms) do
    %{resources: resources, population: pop} = settled(city, now_ms)
    save_resources(city, resources, now_ms, pop["current"] - min(amount, pop["max"]))
  end

  # every task ends now; training batches still waiting in a queue start now too
  defp cheat_city(city, "finishAll", _args, now_ms) do
    now = to_datetime(now_ms)

    Repo.update_all(from(t in Task, where: t.city_id == ^city.id and t.started_at > ^now),
      set: [started_at: now]
    )

    Repo.update_all(
      from(t in Task,
        where: t.city_id == ^city.id and not fragment("coalesce(?->>'phase', '') = 'stationed'", t.data)
      ),
      set: [ends_at: now]
    )

    complete_due(city.id, now)
    :ok
  end

  # anything being built on the slot, or trained in it, is dropped without a refund
  defp cheat_city(city, "setBuilding", %{slot: slot, type: type, level: level}, now_ms) do
    buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)

    case Cheats.place(buildings, slot, type, level) do
      {:error, code} ->
        {:error, code}

      result ->
        Repo.delete_all(from t in Task, where: t.city_id == ^city.id and t.slot == ^slot)

        case result do
          {:remove} ->
            Repo.delete_all(from b in Building, where: b.city_id == ^city.id and b.slot == ^slot)

          {:set, type} ->
            Repo.insert!(%Building{city_id: city.id, slot: slot, type: type, level: level},
              on_conflict: [set: [type: type, level: level]],
              conflict_target: [:city_id, :slot]
            )
        end

        resnapshot(city, to_datetime(now_ms))
        :ok
    end
  end

  # constructions in progress are dropped, as their levels would no longer make sense
  defp cheat_city(city, "levelAll", %{level: level}, now_ms) do
    Repo.delete_all(from t in Task, where: t.city_id == ^city.id and t.kind == "build")
    Repo.update_all(from(b in Building, where: b.city_id == ^city.id), set: [level: level])
    resnapshot(city, to_datetime(now_ms))
  end

  # the whole layout is replaced, so constructions and training queues are dropped without a refund; troops,
  # heroes, research, fortifications and resources stay (warehouses and cottages raise the caps at once)
  defp cheat_city(city, "maxTown", _args, now_ms) do
    Repo.delete_all(from t in Task, where: t.city_id == ^city.id and t.kind in ["build", "train"])
    Repo.delete_all(from b in Building, where: b.city_id == ^city.id)
    Repo.insert_all(Building, Enum.map(Cheats.max_town(), &Map.put(&1, :city_id, city.id)))
    resnapshot(city, to_datetime(now_ms))
  end

  defp cheat_city(city, "heroExp", %{amount: amount}, now_ms) do
    for h <- Repo.all(from h in Hero, where: h.city_id == ^city.id) do
      up = Heroes.gain_exp(h, amount)
      h |> Ecto.Changeset.change(level: up.level, exp: up.exp, points: up.points) |> Repo.update!()
    end

    # higher levels mean higher salaries, taken off the gold rate
    resnapshot(Repo.get!(City, city.id), to_datetime(now_ms))
  end

  # settled to now first, so the new loyalty counts from now
  defp cheat_city(city, "setLoyalty", %{changes: changes}, now_ms) do
    resnapshot(city, to_datetime(now_ms), changes ++ [comfort_at: nil])
  end

  defp cheat_city(city, "resetCity", _args, now_ms) do
    Repo.delete_all(from t in Task, where: t.city_id == ^city.id)
    Repo.delete_all(from h in Hero, where: h.city_id == ^city.id)
    Repo.delete_all(from b in Building, where: b.city_id == ^city.id and b.slot not in ["townhall", "walls"])

    Repo.insert_all(
      Building,
      [
        %{city_id: city.id, slot: "townhall", type: "townhall", level: 1},
        %{city_id: city.id, slot: "walls", type: "walls", level: 1}
      ],
      on_conflict: [set: [level: 1]],
      conflict_target: [:city_id, :slot]
    )

    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set: [
        tax_rate: 10,
        loyalty: 100,
        grievance: 0,
        comfort_at: nil,
        troops: %{},
        inn: %{},
        resources: Game.starter_resources(),
        population: Game.starter_population(),
        synced_at: to_datetime(now_ms)
      ]
    )

    :ok
  end

  defp find_task(city_id, task_id, kinds) do
    case Ecto.UUID.cast(task_id) do
      {:ok, id} ->
        Repo.one(from t in Task, where: t.id == ^id and t.city_id == ^city_id and t.kind in ^kinds)

      :error ->
        nil
    end
  end

  defp researching?(city_id),
    do: Repo.exists?(from t in Task, where: t.city_id == ^city_id and t.kind == "research")

  defp research_of(player_id),
    do: Repo.one(from p in Player, where: p.id == ^player_id, select: p.research) || %{}

  # The training batches of one Barracks, in the order they run.
  defp training_queue(city_id, slot, kind \\ "train"),
    do:
      Repo.all(
        from t in Task,
          where: t.city_id == ^city_id and t.kind == ^kind and t.slot == ^slot,
          order_by: t.ends_at
      )

  # How many people a task took: a training batch's troops x their population; nothing for other tasks.
  defp people(%Task{kind: "train", target_type: troop, target_level: count}),
    do: Data.troop(troop)["population"] * count

  defp people(_task), do: 0

  # After a batch was cancelled or sped up: closes the gap in that Barracks' queue. The batch running now keeps
  # its times; each waiting one starts when the one before it ends (or now), keeping its length.
  defp rechain(city_id, slot, now_ms, kind) do
    Enum.reduce(training_queue(city_id, slot, kind), now_ms, fn t, starts_ms ->
      started_ms = to_ms(t.started_at)
      ends_ms = to_ms(t.ends_at)

      if started_ms <= now_ms do
        ends_ms
      else
        new_ends = starts_ms + (ends_ms - started_ms)

        t
        |> Ecto.Changeset.change(started_at: to_datetime(starts_ms), ends_at: to_datetime(new_ends))
        |> Repo.update!()

        new_ends
      end
    end)
  end

  @doc """
  Finishes every task that is due by now_ms, in every city. For Age3.TaskRunner, which tells the players.
  Returns {player_id, task JSON} for each finished task.
  """
  def finish_due(now_ms) do
    now = to_datetime(now_ms)
    # the task runner sends the attackers taskDone for these, so only the defenders get told
    attacks = arrivals(:all, now, false)

    attacks ++
      (Repo.all(
         from t in Task,
           join: c in City,
           on: c.id == t.city_id,
           where: t.ends_at <= ^now,
           distinct: true,
           select: {c.id, c.player_id}
       )
       |> Enum.flat_map(fn {city_id, player_id} ->
         done = finish_due_in_city(city_id, now)
         Enum.map(done, &{player_id, task_json(&1)})
       end))
  end

  # Attacks on player cities. A march arriving at another player's city changes both cities, so it isn't finished
  # inside its own city's complete_due (which holds only that city's lock). arrivals/2 finishes each due one in a
  # transaction of its own that locks both cities in id order (as cheats do), so two players attacking each other
  # at the same moment can't deadlock. Every command on a city calls it first, as do state/2 and the task runner,
  # oldest arrival first. Returns {attacker's player_id, task JSON} for each, and tells both players' open games.
  defp arrivals(city_ids, now, tell_attacker \\ true) do
    due = from(t in Task, where: not is_nil(t.target_city_id) and t.ends_at <= ^now)

    due =
      case city_ids do
        :all ->
          due

        ids ->
          ids = for id <- ids, {:ok, uuid} <- [Ecto.UUID.cast(id)], do: uuid
          from(t in due, where: t.city_id in ^ids or t.target_city_id in ^ids)
      end

    Repo.all(from(t in due, order_by: [t.ends_at, t.id], select: t.id))
    |> Enum.flat_map(&arrive(&1, tell_attacker))
  end

  defp arrive(task_id, tell_attacker) do
    with %Task{} = first <- Repo.get(Task, task_id),
         {:ok, outcome} <- Repo.transaction(fn -> arrive_locked(first) end) do
      case outcome do
        :retry ->
          arrive(task_id, tell_attacker)

        :gone ->
          []

        {task, attacker, players} ->
          for p <- Enum.uniq(players), p != attacker, do: tell(p, "attacked")
          if tell_attacker, do: tell(attacker, "march")
          [{attacker, task_json(task)}]
      end
    else
      _ -> []
    end
  end

  # Inside the transaction: locks both cities, then the task again (another process may have finished it, or a
  # capture moved it to another city since it was read).
  defp arrive_locked(first) do
    ids = Enum.uniq(Enum.sort([first.city_id, first.target_city_id]))
    Repo.all(from c in City, where: c.id in ^ids, order_by: c.id, lock: "FOR UPDATE", select: c.id)
    t = Repo.one(from t in Task, where: t.id == ^first.id, lock: "FOR UPDATE")

    cond do
      t == nil or t.target_city_id == nil ->
        :gone

      t.city_id != first.city_id or t.target_city_id != first.target_city_id ->
        :retry

      true ->
        # both cities as they stood the moment the attack arrived
        complete_due(t.city_id, t.ends_at)
        complete_due(t.target_city_id, t.ends_at)
        attacker = Repo.get!(City, t.city_id)
        {task, players} = at_city(attacker, Repo.get!(City, t.target_city_id), t)
        Repo.delete!(t)
        resnapshot(Repo.get!(City, attacker.id), t.ends_at)
        {task, attacker.player_id, players}
    end
  end

  # Pushes a player's new state to their open games (none in tests, where nothing is registered).
  defp tell(player_id, reason) do
    if Process.whereis(Age3.Players), do: Age3.Session.notify(player_id, reason)
  end

  # A march arriving at a player's city (both locked), by its mission. Returns the task with the outcome added and
  # the other players whose games changed.
  defp at_city(att, def, %Task{data: d} = t) do
    case d["mission"] || "attack" do
      "attack" -> attack_city(att, def, t)
      "scout" -> scout_city(att, def, t)
      "transport" -> deliver(att, def, t)
      "reinforce" -> reinforce(att, def, t)
    end
  end

  # Scouting a player's city (Age3.Scout): what the sender's Informatics, Beacon Tower and hero can see of it,
  # against the owner's Informatics and defending hero; with its gate open, its scouts fight yours. Both get a
  # report; the scouted lord only learns who looked and whether it worked.
  defp scout_city(%City{player_id: owner} = att, %City{player_id: owner}, %Task{data: d} = t) do
    # captured on the way: nothing to scout any more
    return_home(att, t, d["troops"], %{})
    {%{t | data: Map.merge(d, %{"won" => nil, "loot" => %{}})}, []}
  end

  defp scout_city(att, def, %Task{data: d} = t) do
    at_ms = to_ms(t.ends_at)
    s = scout_level(att, d)
    def_buildings = Repo.all(from b in Building, where: b.city_id == ^def.id)
    def_research = Research.in_city(research_of(def.player_id), def_buildings)
    guard = defending_hero(def)
    open? = Pvp.gate_open?(def.gate_open, def.loyalty)
    garrison = defending_troops(def)
    level = Scout.city_level(def_research, guard && guard.intelligence)
    sent = Map.get(d["troops"], "scout", 0)
    outcome = Scout.outcome(s, sent, {:city, if(open?, do: Map.get(garrison, "scout", 0))})

    seen =
      if outcome == :ok do
        %{resources: resources} = settled(def, at_ms)

        Scout.report(
          %{
            "resources" => Map.new(resources, fn {k, v} -> {k, v["amount"]} end),
            "walls" => Enum.find_value(def_buildings, 0, &(&1.slot == "walls" && &1.level)),
            "troops" => garrison,
            "forts" => def.forts || %{},
            "research" => def_research,
            "gateOpen" => open?,
            "buildings" =>
              for(
                b <- Enum.sort_by(def_buildings, & &1.slot),
                do: %{"type" => b.type, "level" => b.level, "slot" => b.slot}
              ),
            "heroes" =>
              Repo.all(
                from h in Hero,
                  where: h.city_id == ^def.id,
                  select: %{"name" => h.name, "level" => h.level, "status" => h.status}
              )
          },
          Scout.detail(s, level)
        )
      end

    names = player_names([att.player_id, def.player_id])
    where = "#{def.name} (#{def.x},#{def.y})"
    report = scout_report(att, t, outcome, seen, where)

    mission_report(
      def,
      t,
      "scout",
      "scouted",
      outcome == :ok,
      if(outcome == :ok,
        do: "#{names[att.player_id]} scouted #{where}",
        else: "#{names[att.player_id]} failed to scout #{where}"
      ),
      %{scout: %{"by" => names[att.player_id], "failed" => outcome != :ok}}
    )

    return_home(att, t, scouts_back(d["troops"], outcome), %{})

    {%{t | data: Map.merge(d, %{"won" => outcome == :ok, "reportId" => report.id, "loot" => %{}})},
     [def.player_id]}
  end

  # A transport arriving: its cargo goes into the city's storage (it can go over the cap, like loot), the troops
  # turn round empty. Both lords get a report.
  defp deliver(att, def, %Task{data: d} = t) do
    cargo = d["cargo"] || %{}
    resnapshot(def, t.ends_at)
    def = Repo.get!(City, def.id)

    Repo.update_all(from(c in City, where: c.id == ^def.id),
      set: [resources: Cheats.add_resources(def.resources, cargo)]
    )

    names = player_names([att.player_id, def.player_id])
    where = "#{def.name} (#{def.x},#{def.y})"
    report = mission_report(att, t, "transport", "attack", true, "Delivered to #{where}", %{loot: cargo})

    if def.player_id != att.player_id do
      mission_report(def, t, "transport", "defence", true, "#{names[att.player_id]} delivered to #{where}", %{
        loot: cargo
      })
    end

    return_home(att, t, d["troops"], %{})
    {%{t | data: Map.merge(d, %{"won" => true, "reportId" => report.id, "loot" => %{}})}, [def.player_id]}
  end

  # Reinforcements arriving. Into one of your own cities: the troops join it for good. Into an ally's city: they
  # stay there (a "stationed" march with no end) and fight for it while its gate is open, eating its food, until
  # their lord recalls them; if the ally no longer takes them they turn round.
  defp reinforce(%City{player_id: owner} = att, %City{player_id: owner} = def, %Task{data: d} = t) do
    troops = Enum.reduce(d["troops"], def.troops, fn {type, n}, acc -> Train.add(acc, type, n) end)
    Repo.update_all(from(c in City, where: c.id == ^def.id), set: [troops: troops])
    resnapshot(Repo.get!(City, def.id), t.ends_at)
    where = "#{def.name} (#{def.x},#{def.y})"
    report = mission_report(att, t, "reinforce", "attack", true, "Troops arrived in #{where}", %{})
    {%{t | data: Map.merge(d, %{"won" => true, "reportId" => report.id, "loot" => %{}})}, []}
  end

  defp reinforce(att, def, %Task{data: d} = t) do
    where = "#{def.name} (#{def.x},#{def.y})"

    if can_garrison?(def, att.player_id) do
      Repo.insert!(%Task{
        city_id: att.id,
        kind: "march",
        label: "Stationed in #{where}",
        target_type: "reinforce",
        target_level: t.target_level,
        target_city_id: def.id,
        cost: %{},
        data: Map.merge(d, %{"phase" => "stationed", "hostName" => def.name}),
        started_at: t.ends_at,
        ends_at: @never
      })

      resnapshot(Repo.get!(City, def.id), t.ends_at)
      names = player_names([att.player_id, def.player_id])
      report = mission_report(att, t, "reinforce", "attack", true, "Troops stationed in #{where}", %{})

      mission_report(
        def,
        t,
        "reinforce",
        "defence",
        true,
        "#{names[att.player_id]}'s troops arrived in #{where}",
        %{}
      )

      {%{t | data: Map.merge(d, %{"won" => true, "reportId" => report.id, "loot" => %{}})}, [def.player_id]}
    else
      report =
        mission_report(att, t, "reinforce", "attack", false, "#{where} no longer takes your troops", %{})

      return_home(att, t, d["troops"], %{})
      {%{t | data: Map.merge(d, %{"won" => false, "reportId" => report.id, "loot" => %{}})}, []}
    end
  end

  # Troops of other players stationed in a city: their stationed marches.
  defp stationed_in(city_id) do
    Repo.all(
      from t in Task,
        where:
          t.target_city_id == ^city_id and t.kind == "march" and
            fragment("coalesce(?->>'phase', '') = 'stationed'", t.data)
    )
  end

  # Everything that fights for a city with its gate open: its own troops and its allies' stationed ones.
  defp defending_troops(city) do
    Enum.reduce(stationed_in(city.id), city.troops || %{}, fn t, acc ->
      Enum.reduce(t.data["troops"], acc, fn {type, n}, a -> Train.add(a, type, n) end)
    end)
  end

  # The troops a city feeds: its own and its allies' stationed ones.
  defp fed_troops(city_id, troops) do
    Enum.reduce(stationed_in(city_id), troops || %{}, fn t, acc ->
      Enum.reduce(t.data["troops"], acc, fn {type, n}, a -> Train.add(a, type, n) end)
    end)
  end

  # The scout level of a march from city (Age3.Scout.level/3): its Informatics and Beacon Tower, and its hero.
  defp scout_level(city, d) do
    buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
    research = Research.in_city(research_of(city.player_id), buildings)
    hero = d["heroId"] && Repo.get(Hero, d["heroId"])

    Scout.level(
      Research.level_of(research, "informatics"),
      Build.level_of(buildings, "beacontower"),
      hero && hero.intelligence
    )
  end

  # What comes home from a scout: everything, or everything but the scouts after a failure.
  defp scouts_back(troops, :ok), do: troops
  defp scouts_back(troops, _failed), do: Map.delete(troops, "scout")

  defp scout_report(city, t, outcome, seen, where) do
    {title, scout} =
      case outcome do
        :ok -> {"Scouted #{where}", seen}
        {:error, why} -> {"Scouting failed at #{where}", %{"failed" => why}}
      end

    mission_report(city, t, "scout", "scout", outcome == :ok, title, %{scout: scout})
  end

  # A report with no battle, for a mission (kind) that arrived: side "attack"/"defence"/"scout"/"scouted".
  defp mission_report(city, t, kind, side, won, title, extra) do
    Repo.insert!(
      struct(
        Report,
        Map.merge(
          %{
            player_id: city.player_id,
            city_id: city.id,
            title: title,
            x: t.data["x"],
            y: t.data["y"],
            won: won,
            kind: kind,
            side: side,
            loot: %{},
            fought_at: t.ends_at
          },
          extra
        )
      )
    )
  end

  defp player_names(ids),
    do: Map.new(Repo.all(from p in Player, where: p.id in ^Enum.uniq(ids), select: {p.id, p.name}))

  # Are these two players allies (the same alliance)? A player is their own ally.
  defp allies?(a, a), do: true

  defp allies?(a, b), do: AllianceStore.relation(a, b) == "alliance"

  # The battle at a player city (both locked). Fights with the city as it stands, takes loot and loyalty, maybe
  # captures it, writes a report for each side and sends the survivors home. Returns the task with the outcome
  # added and the other players whose games changed.
  defp attack_city(%City{player_id: owner} = att, %City{player_id: owner} = home, %Task{data: d} = t) do
    # the city is the attacker's own now (they captured it on the way): the army just turns round
    return_home(att, t, d["troops"], %{})
    {%{t | data: Map.merge(d, %{"won" => nil, "loot" => %{}})}, [home.player_id]}
  end

  defp attack_city(att, def, %Task{data: d} = t) do
    at_ms = to_ms(t.ends_at)
    resnapshot(def, t.ends_at)
    def = Repo.get!(City, def.id)
    att_buildings = Repo.all(from b in Building, where: b.city_id == ^att.id)
    def_buildings = Repo.all(from b in Building, where: b.city_id == ^def.id)
    att_research = Research.in_city(research_of(att.player_id), att_buildings)
    def_research = Research.in_city(research_of(def.player_id), def_buildings)
    %{resources: resources} = settled(def, at_ms)
    loyalty = def.loyalty
    open? = Pvp.gate_open?(def.gate_open, loyalty)
    hero = Repo.get(Hero, d["heroId"])
    guard = defending_hero(def)
    walls = Enum.find_value(def_buildings, 0, &(&1.slot == "walls" && &1.level))

    # allies stationed in the city fight with its own troops while the gate is open
    garrison = defending_troops(def)

    {defender, forts, settings} =
      Pvp.battle(garrison, combat_tech(def_research), guard && combat_hero(guard), walls, open?, def.forts)

    attacker = %{
      Combat.default_army()
      | troops: d["troops"],
        tech: combat_tech(att_research),
        hero: combat_hero(hero),
        heal_percent: 0
    }

    result =
      Combat.simulate(%{attacker: attacker, defender: defender, fortifications: forts, settings: settings})

    battle_points(att.player_id, def.player_id, result)
    won = result.winner == :attacker
    survivors = for s <- result.attacker.troops, s.survived > 0, into: %{}, do: {s.type, s.survived}

    loot =
      if won do
        amounts = Map.new(resources, fn {k, v} -> {k, v["amount"]} end)
        free = Pvp.plunderable(amounts, def_buildings, def_research, Pvp.privateering(att_research))
        March.loot(free, March.load(survivors, att_research))
      else
        %{}
      end

    save_resources(def, Build.spend(resources, loot), at_ms)

    Repo.update_all(from(c in City, where: c.id == ^def.id),
      set: [
        troops: Pvp.troops_left(def.troops, result, open?, garrison),
        forts: Forts.after_battle(def.forts, result)
      ]
    )

    if open?, do: thin_stationed(def.id, result, garrison)

    hero_report = hero && gain_hero_exp(hero, March.hero_exp(result))
    guard_report = guard && gain_hero_exp(guard, result.attacker.total_lost)
    owned = Repo.aggregate(from(c in City, where: c.player_id == ^att.player_id), :count)
    change = won && Pvp.after_loss(loyalty, def.grievance, owned)
    captured = change != false and change.captured

    cond do
      captured ->
        capture(def, att.player_id, t.ends_at)

      change ->
        Repo.update_all(from(c in City, where: c.id == ^def.id),
          set: [loyalty: change.loyalty, grievance: change.grievance]
        )

      true ->
        :ok
    end

    after_loyalty =
      cond do
        captured -> Pvp.captured_loyalty()
        change -> change.loyalty
        true -> loyalty
      end

    loyalty_report = %{"before" => loyalty, "after" => after_loyalty, "captured" => captured}

    names =
      Map.new(
        Repo.all(from p in Player, where: p.id in ^[att.player_id, def.player_id], select: {p.id, p.name})
      )

    where = "#{def.name} (#{def.x},#{def.y})"

    att_title =
      cond do
        captured -> "Captured #{where}"
        won -> "Victory against #{where}"
        true -> "Defeat against #{where}"
      end

    def_title =
      cond do
        captured -> "#{where} was captured by #{names[att.player_id]}"
        won -> "#{where} lost to #{names[att.player_id]}"
        true -> "#{where} held against #{names[att.player_id]}"
      end

    common = %{
      x: def.x,
      y: def.y,
      loot: loot,
      loyalty: loyalty_report,
      result: Combat.to_json(result),
      fought_at: t.ends_at
    }

    report =
      Repo.insert!(
        struct(
          Report,
          Map.merge(common, %{
            player_id: att.player_id,
            city_id: att.id,
            title: att_title,
            won: won,
            hero: hero_report,
            side: "attack"
          })
        )
      )

    Repo.insert!(
      struct(
        Report,
        Map.merge(common, %{
          player_id: def.player_id,
          city_id: def.id,
          title: def_title,
          won: not won,
          hero: guard_report,
          side: "defence"
        })
      )
    )

    return_home(att, t, survivors, loot)
    unless captured, do: resnapshot(Repo.get!(City, def.id), t.ends_at)

    {%{t | data: Map.merge(d, %{"won" => won, "reportId" => report.id, "loot" => loot})}, [def.player_id]}
  end

  # Allies' stationed troops after a battle at the city they guard: each loses the same share of each type as
  # the whole garrison did; a group with nobody left is gone.
  defp thin_stationed(city_id, result, garrison) do
    for t <- stationed_in(city_id) do
      left = Pvp.share_left(t.data["troops"], result, garrison)

      if Enum.all?(left, fn {_k, n} -> n == 0 end),
        do: Repo.delete!(t),
        else: t |> Ecto.Changeset.change(data: Map.put(t.data, "troops", left)) |> Repo.update!()
    end
  end

  # The way home for a march that has arrived: a new task back to its city, as long as the way out took.
  defp return_home(city, %Task{data: d} = t, troops, loot) do
    Repo.insert!(%Task{
      city_id: city.id,
      kind: "march",
      label: "Returning from (#{d["x"]},#{d["y"]})",
      target_type: "attack",
      target_level: t.target_level,
      cost: %{},
      data: Map.merge(d, %{"phase" => "back", "troops" => troops, "loot" => loot}),
      started_at: t.ends_at,
      ends_at: to_datetime(to_ms(t.ends_at) + d["seconds"] * 1000)
    })
  end

  # The city's defending hero, if it is at home and free to fight (idle, or the mayor).
  defp defending_hero(%City{defender_hero_id: nil}), do: nil

  defp defending_hero(city) do
    Repo.one(
      from h in Hero,
        where: h.id == ^city.defender_hero_id and h.city_id == ^city.id and h.status in ["idle", "mayor"]
    )
  end

  # A captured city changes hands (plans/capture-loyalty-plan.md, 3.4, with TJ's answers): buildings and resources
  # stay; troops at home and everything queued (builds, research, training) are lost; the heroes at home become
  # the new owner's captives (persuade or release them in the Feasting Hall). The old owner's marches out of the
  # city go home to their nearest other city instead, or to a new empty city if this was their last.
  defp capture(city, new_owner, at) do
    old_owner = city.player_id
    Repo.delete_all(from t in Task, where: t.city_id == ^city.id and t.kind != "march")

    if Repo.exists?(from t in Task, where: t.city_id == ^city.id and t.kind == "march") do
      home = nearest_city(old_owner, city) || new_city(old_owner, Repo.get!(Player, old_owner).name)

      Repo.update_all(from(t in Task, where: t.city_id == ^city.id and t.kind == "march"),
        set: [city_id: home.id]
      )

      Repo.update_all(from(h in Hero, where: h.city_id == ^city.id and h.status == "marching"),
        set: [city_id: home.id]
      )
    end

    unless Repo.exists?(from c in City, where: c.player_id == ^old_owner and c.id != ^city.id),
      do: new_city(old_owner, Repo.get!(Player, old_owner).name)

    Repo.update_all(from(h in Hero, where: h.city_id == ^city.id), set: [status: "captive"])

    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set: [
        player_id: new_owner,
        troops: %{},
        loyalty: Pvp.captured_loyalty(),
        grievance: 0,
        comfort_at: nil,
        gate_open: false,
        defender_hero_id: nil,
        inn: %{}
      ]
    )

    # the new owner's research, no heroes' salaries (captives aren't paid) and no troops from now on
    resnapshot(Repo.get!(City, city.id), at)
  end

  defp nearest_city(player_id, from) do
    Repo.all(from c in City, where: c.player_id == ^player_id and c.id != ^from.id)
    |> Enum.min_by(&March.distance({&1.x, &1.y}, {from.x, from.y}), fn -> nil end)
  end

  @doc "When the next task is due, in epoch milliseconds, or nil when nothing is running."
  def next_due do
    case Repo.one(from t in Task, select: min(t.ends_at)) do
      nil -> nil
      ends_at -> to_ms(ends_at)
    end
  end

  defp finish_due_in_city(city_id, now) do
    if Repo.exists?(from t in Task, where: t.city_id == ^city_id and t.ends_at <= ^now) do
      {:ok, done} =
        Repo.transaction(fn ->
          Repo.one(from c in City, where: c.id == ^city_id, lock: "FOR UPDATE", select: c.id)
          complete_due(city_id, now)
        end)

      done
    else
      []
    end
  end

  # Inside a transaction holding the city's lock: applies each finished task (a building's new level, the
  # player's new research level, trained troops, a march's battle or return) and drops it. Production changes the moment a task finishes, so resources are
  # settled up to that moment at the old rates and saved as a new snapshot with the new rates and population.
  # Research also changes the player's other cities; refresh_stale gives them the new rates on the next state.
  defp complete_due(city_id, now) do
    # attacks on player cities are finished by arrivals/2, which locks both cities
    tasks =
      Repo.all(
        from t in Task,
          where: t.city_id == ^city_id and t.ends_at <= ^now and is_nil(t.target_city_id),
          order_by: t.ends_at
      )

    done =
      for t <- tasks do
        city = Repo.get!(City, city_id)
        applied = apply_task(city, t)
        Repo.delete!(t)
        # read again: a returning march has already added its loot to a new snapshot
        resnapshot(Repo.get!(City, city_id), t.ends_at)
        # a march that arrived reports how the battle went
        case applied do
          %Task{} -> applied
          _other -> t
        end
      end

    # a march that arrived starts its way back, which may already be over too
    if tasks == [], do: [], else: done ++ complete_due(city_id, now)
  end

  # a demolition that took the building down to nothing leaves the plot empty
  defp apply_task(city, %Task{kind: "build", target_level: 0, data: %{"demolish" => true}} = t) do
    Repo.delete_all(from b in Building, where: b.city_id == ^t.city_id and b.slot == ^t.slot)
    refund(city, t)
  end

  defp apply_task(city, %Task{kind: "build", data: %{"demolish" => true}} = t) do
    Repo.update_all(from(b in Building, where: b.city_id == ^t.city_id and b.slot == ^t.slot),
      set: [level: t.target_level]
    )

    refund(city, t)
  end

  defp apply_task(_city, %Task{kind: "build"} = t) do
    Repo.insert!(%Building{city_id: t.city_id, slot: t.slot, type: t.target_type, level: t.target_level},
      on_conflict: [set: [type: t.target_type, level: t.target_level]],
      conflict_target: [:city_id, :slot]
    )
  end

  # only ever raises a level, in case the same level somehow finished twice
  defp apply_task(city, %Task{kind: "research"} = t) do
    Repo.update_all(
      from(p in Player,
        where: p.id == ^city.player_id,
        update: [
          set: [
            research:
              fragment(
                "? || jsonb_build_object(?::text, greatest(coalesce((?->>?::text)::int, 0), ?::int))",
                p.research,
                ^t.target_type,
                p.research,
                ^t.target_type,
                ^t.target_level
              )
          ]
        ]
      ),
      []
    )
  end

  defp apply_task(city, %Task{kind: "fort"} = t) do
    forts = Map.update(city.forts || %{}, t.target_type, t.target_level, &(&1 + t.target_level))
    Repo.update_all(from(c in City, where: c.id == ^city.id), set: [forts: forts])
  end

  defp apply_task(city, %Task{kind: "train"} = t) do
    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set: [troops: Train.add(city.troops, t.target_type, t.target_level)]
    )
  end

  # A march arriving at its NPC (or a made-up lord's town or a free historic city, fought the same way: Age3.Lord,
  # Age3.Historic): the battle, as at the moment it arrived. The NPC is locked (after the city, as always) so two
  # marches arriving at once fight one after the other. Saves what is left of the NPC, the hero's exp and a
  # report, and sends the survivors home with their loot; a historic city also loses loyalty and may be captured.
  # Returns the task with the outcome added. Marches sent before lords' towns existed have no "target".
  defp apply_task(city, %Task{kind: "march", data: %{"phase" => "out", "target" => "historic"} = d} = t) do
    # someone captured it while this march was on its way: no battle, the army turns round
    if city_at(d["x"], d["y"]) do
      return_home(city, t, d["troops"], %{})
      %{t | data: Map.merge(d, %{"won" => nil, "loot" => %{}})}
    else
      fight_npc(city, t, "historic")
    end
  end

  defp apply_task(city, %Task{kind: "march", data: %{"phase" => "out", "mission" => "scout"}} = t),
    do: scout_tile(city, t)

  defp apply_task(city, %Task{kind: "march", data: %{"phase" => "out", "mission" => "found"}} = t),
    do: found_city(city, t)

  defp apply_task(city, %Task{kind: "march", data: %{"phase" => "out", "target" => "valley"}} = t),
    do: fight_valley(city, t)

  defp apply_task(city, %Task{kind: "march", data: %{"phase" => "out"} = d} = t),
    do: fight_npc(city, t, d["target"] || "npc")

  # A march home: the troops rejoin the city, the hero is free again and the loot goes into storage (it can go
  # over the cap, like a cheat's resources).
  defp apply_task(city, %Task{kind: "march", data: %{"phase" => "back"} = d} = t) do
    resnapshot(city, t.ends_at)
    city = Repo.get!(City, city.id)
    resources = Cheats.add_resources(city.resources, d["loot"] || %{})
    troops = Enum.reduce(d["troops"], city.troops, fn {type, n}, acc -> Train.add(acc, type, n) end)
    Repo.update_all(from(c in City, where: c.id == ^city.id), set: [resources: resources, troops: troops])

    if d["heroId"] do
      Repo.update_all(from(h in Hero, where: h.id == ^d["heroId"] and h.status == "marching"),
        set: [status: "idle"]
      )
    end
  end

  # What an NPC-like target (an NPC, a lord's town or a free historic city) holds when full, its name and how
  # fast it refills.
  defp npc_spec(kind, x, y, level, at_ms) do
    case kind do
      "lord" ->
        {Lord.full(x, y, level), Lord.name(x, y), Data.npc_regen_seconds()}

      "historic" ->
        {Historic.full(x, y, level, Historic.day(at_ms)), Historic.name(x, y), Historic.regen_seconds()}

      _ ->
        {Npc.full(level), "Lv#{level} NPC", Data.npc_regen_seconds()}
    end
  end

  # A demolition's refund, added (up to the caps) as of the moment it finished.
  defp refund(city, %Task{data: %{"refund" => refund}} = t) do
    at = to_ms(Enum.max([city.synced_at, t.ends_at], DateTime))
    save_resources(city, Economy.add_capped(settled(city, at).resources, refund), at)
  end

  defp fight_npc(city, %Task{data: d} = t, kind) do
    at_ms = to_ms(t.ends_at)
    {x, y, level} = {d["x"], d["y"], t.target_level}
    historic? = kind == "historic"
    {full, what, periods} = npc_spec(kind, x, y, level, at_ms)
    {npc, row} = lock_npc(x, y, level, full, at_ms, periods, historic?)
    buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
    research = Research.in_city(research_of(city.player_id), buildings)
    hero = Repo.get(Hero, d["heroId"])

    {defender, forts, settings} =
      if historic?, do: Historic.battle(npc, level), else: Npc.battle(npc, level)

    attacker = %{
      Combat.default_army()
      | troops: d["troops"],
        tech: combat_tech(research),
        hero: combat_hero(hero),
        heal_percent: 0
    }

    result =
      Combat.simulate(%{attacker: attacker, defender: defender, fortifications: forts, settings: settings})

    won = result.winner == :attacker
    survivors = for s <- result.attacker.troops, s.survived > 0, into: %{}, do: {s.type, s.survived}
    loot = if won, do: March.loot(npc["resources"], March.load(survivors, research)), else: %{}
    left = Npc.after_battle(npc, result, loot)

    # a historic city's loyalty: back up since its last battle, then down 3 for a win; at 0 a win captures it
    {loyalty_report, captured} =
      if historic? do
        before = Historic.loyalty(row.loyalty, to_ms(row.updated_at), at_ms)
        owned = Repo.aggregate(from(c in City, where: c.player_id == ^city.player_id), :count)
        change = if won, do: Historic.after_win(before, owned), else: %{loyalty: before, captured: false}
        after_ = if change.captured, do: Pvp.captured_loyalty(), else: change.loyalty
        {%{"before" => before, "after" => after_, "captured" => change.captured}, change.captured}
      else
        {nil, false}
      end

    Repo.update_all(from(n in NpcState, where: n.x == ^x and n.y == ^y),
      set: [
        troops: left["troops"],
        forts: left["forts"],
        resources: left["resources"],
        loyalty: if(loyalty_report, do: loyalty_report["after"], else: 100),
        updated_at: t.ends_at
      ]
    )

    if captured, do: capture_historic(city.player_id, x, y, level, t.ends_at)

    hero_report = hero && gain_hero_exp(hero, March.hero_exp(result))
    # lords' towns drop no medals; historic cities roll theirs for killing 5% of the garrison, won or lost
    medals =
      case kind do
        "lord" -> %{}
        "historic" -> if Historic.medals?(full, result), do: Titles.roll_historic(), else: %{}
        _ -> if Titles.full_clear?(won, npc, full, result), do: Titles.roll_npc(level), else: %{}
      end

    if medals != %{}, do: add_medals(city.player_id, medals)

    outcome =
      cond do
        captured -> "Captured"
        won -> "Victory against"
        true -> "Defeat against"
      end

    report =
      Repo.insert!(%Report{
        player_id: city.player_id,
        city_id: city.id,
        title: "#{outcome} #{what} (#{x},#{y})",
        x: x,
        y: y,
        won: won,
        loot: loot,
        medals: medals,
        loyalty: loyalty_report,
        hero: hero_report,
        result: Combat.to_json(result),
        fought_at: t.ends_at
      })

    back = Map.merge(d, %{"phase" => "back", "troops" => survivors, "loot" => loot})

    Repo.insert!(%Task{
      city_id: city.id,
      kind: "march",
      label: "Returning from (#{x},#{y})",
      target_type: "attack",
      target_level: level,
      cost: %{},
      data: back,
      started_at: t.ends_at,
      ends_at: to_datetime(at_ms + d["seconds"] * 1000)
    })

    %{t | data: Map.merge(d, %{"won" => won, "reportId" => report.id, "loot" => loot, "medals" => medals})}
  end

  # Scouting a tile that isn't a player's city (Age3.Scout): an NPC, a lord's town or a free historic city (what
  # it holds now, as an attack would find it), a valley (its garrison, or who holds it) or a flat (nothing). The
  # scouts come home either way, less the scouts themselves after a failure.
  defp scout_tile(city, %Task{data: d} = t) do
    at_ms = to_ms(t.ends_at)
    {x, y, level} = {d["x"], d["y"], t.target_level}
    s = scout_level(city, d)
    sent = Map.get(d["troops"], "scout", 0)

    {target, what, name} =
      case d["target"] do
        "flat" ->
          {:flat, %{}, "flat"}

        "valley" ->
          case Repo.one(from v in ValleyHold, where: v.x == ^x and v.y == ^y, preload: :city) do
            %ValleyHold{city: holder} ->
              {{:level, level}, %{"troops" => %{}, "holder" => holder.name}, "Lv#{level} valley"}

            nil ->
              {npc, _row} = lock_npc(x, y, level, Valley.full(level), at_ms, valley_periods(), false)
              {{:level, level}, %{"troops" => npc["troops"]}, "Lv#{level} valley"}
          end

        kind ->
          {full, name, periods} = npc_spec(kind, x, y, level, at_ms)
          {npc, _row} = lock_npc(x, y, level, full, at_ms, periods, kind == "historic")

          walls = if kind == "historic", do: full["walls"] || 10, else: level

          {{:level, level},
           %{
             "resources" => npc["resources"],
             "walls" => walls,
             "troops" => npc["troops"],
             "forts" => npc["forts"],
             "research" => %{"all" => if(kind == "historic", do: 10, else: level)}
           }, name}
      end

    outcome = Scout.outcome(s, sent, target)

    seen =
      if outcome == :ok do
        l = with {:level, l} <- target, do: l, else: (_ -> 0)
        report = Scout.report(what, Scout.detail(s, l))
        if what["holder"], do: Map.put(report, "holder", what["holder"]), else: report
      end

    report = scout_report(city, t, outcome, seen, "#{name} (#{x},#{y})")
    return_home(city, t, scouts_back(d["troops"], outcome), %{})
    %{t | data: Map.merge(d, %{"won" => outcome == :ok, "reportId" => report.id, "loot" => %{}})}
  end

  defp valley_periods, do: {Data.valley_regen_seconds(), Data.valley_regen_seconds()}

  # Founding a city on a flat (wiki: 250 workers and 10,000 of each resource): the workers settle it and the
  # resources become its stock; any other troops go home. If someone built there first, or the player can't hold
  # another city any more, everything comes back.
  defp found_city(city, %Task{data: d} = t) do
    {x, y} = {d["x"], d["y"]}
    player = Repo.get!(Player, city.player_id)
    cities = Repo.aggregate(from(c in City, where: c.player_id == ^player.id), :count)
    free? = city_at(x, y) == nil and World.tile_at(x, y).kind == "flat" and not Game.historic_city?(x, y)

    if free? and cities < Titles.city_cap(player.title) do
      cargo = d["cargo"] || %{}

      resources =
        Map.new(Game.starter_resources(), fn {k, v} -> {k, %{v | "amount" => Map.get(cargo, k, 0)}} end)

      new =
        Repo.insert!(%City{
          player_id: player.id,
          name: "#{player.name}'s City #{cities + 1}",
          x: x,
          y: y,
          resources: resources,
          population: Game.starter_population(),
          synced_at: t.ends_at
        })

      Repo.insert_all(Building, [
        %{city_id: new.id, slot: "townhall", type: "townhall", level: 1},
        %{city_id: new.id, slot: "walls", type: "walls", level: 1}
      ])

      resnapshot(Repo.get!(City, new.id), t.ends_at)
      report = mission_report(city, t, "found", "attack", true, "Founded #{new.name} (#{x},#{y})", %{})
      rest = Map.update!(d["troops"], "worker", &(&1 - March.found_workers()))
      rest = for {k, n} <- rest, n > 0, into: %{}, do: {k, n}
      if rest != %{}, do: return_home(city, t, rest, %{})
      %{t | data: Map.merge(d, %{"won" => true, "reportId" => report.id, "loot" => %{}})}
    else
      why = if free?, do: "you hold as many cities as your title allows", else: "the land is taken"

      report =
        mission_report(city, t, "found", "attack", false, "Couldn't found a city at (#{x},#{y}): #{why}", %{})

      return_home(city, t, d["troops"], d["cargo"] || %{})
      %{t | data: Map.merge(d, %{"won" => false, "reportId" => report.id, "loot" => %{}})}
    end
  end

  # An attack on a valley (Age3.Valley). A free valley fights with its garrison (refilling like an NPC's); a held
  # one has nobody in it, so the attack wins at once and takes it from its holder, who gets a report. A win takes
  # the valley for the attacking city if it holds fewer than its Town Hall level.
  defp fight_valley(city, %Task{data: d} = t) do
    at_ms = to_ms(t.ends_at)
    {x, y, level} = {d["x"], d["y"], t.target_level}

    holder =
      Repo.one(from v in ValleyHold, where: v.x == ^x and v.y == ^y, lock: "FOR UPDATE", preload: :city)

    {garrison, npc} =
      if holder do
        {%{}, nil}
      else
        {npc, _row} = lock_npc(x, y, level, Valley.full(level), at_ms, valley_periods(), false)
        {npc["troops"], npc}
      end

    buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
    research = Research.in_city(research_of(city.player_id), buildings)
    hero = d["heroId"] && Repo.get(Hero, d["heroId"])
    {defender, forts, settings} = Valley.battle(garrison, level)

    attacker = %{
      Combat.default_army()
      | troops: d["troops"],
        tech: combat_tech(research),
        hero: combat_hero(hero),
        heal_percent: 0
    }

    result =
      Combat.simulate(%{attacker: attacker, defender: defender, fortifications: forts, settings: settings})

    won = result.winner == :attacker
    survivors = for s <- result.attacker.troops, s.survived > 0, into: %{}, do: {s.type, s.survived}

    if npc do
      left = Npc.after_battle(npc, result, %{})

      Repo.update_all(from(n in NpcState, where: n.x == ^x and n.y == ^y),
        set: [troops: left["troops"], updated_at: t.ends_at]
      )
    end

    town_hall = Build.level_of(buildings, "townhall")
    own? = holder != nil and holder.city.player_id == city.player_id
    took = won and not own? and valley_count(city.id) < Valley.cap(town_hall)
    terrain = World.terrain(x, y)
    name = "Lv#{level} #{Data.terrain(terrain)["name"]}"

    if took do
      if holder do
        # its old city loses the bonus from its next snapshot on (refresh_stale), so no second city is locked here
        Repo.delete!(holder)
        mission_report(holder.city, t, "valley", "defence", false, "Lost the #{name} (#{x},#{y})", %{})
      end

      Repo.insert!(%ValleyHold{
        city_id: city.id,
        x: x,
        y: y,
        level: level,
        terrain: terrain,
        taken_at: t.ends_at
      })
    end

    hero_report = hero && gain_hero_exp(hero, March.hero_exp(result))

    title =
      cond do
        took ->
          "Took the #{name} (#{x},#{y})"

        won ->
          "Victory at the #{name} (#{x},#{y}), but #{city.name} holds all the valleys its Town Hall allows"

        true ->
          "Defeat at the #{name} (#{x},#{y})"
      end

    report =
      Repo.insert!(%Report{
        player_id: city.player_id,
        city_id: city.id,
        title: title,
        x: x,
        y: y,
        won: won,
        loot: %{},
        hero: hero_report,
        result: Combat.to_json(result),
        fought_at: t.ends_at
      })

    return_home(city, t, survivors, %{})
    %{t | data: Map.merge(d, %{"won" => won, "reportId" => report.id, "loot" => %{}})}
  end

  # A captured historic city (Age3.Historic): a new city of the attacker's on its tile, keeping its name, with
  # Town Hall 10, Walls 10, four fields, a little of each resource and 50 people.
  defp capture_historic(player_id, x, y, level, at) do
    stock = Historic.captured_stock()

    resources =
      Map.new(Game.starter_resources(), fn {k, v} -> {k, %{v | "amount" => stock.resources}} end)

    city =
      Repo.insert!(%City{
        player_id: player_id,
        name: Historic.name(x, y),
        x: x,
        y: y,
        historic_level: level,
        loyalty: Pvp.captured_loyalty(),
        resources: resources,
        population: %{"current" => stock.people, "max" => stock.people, "idle" => stock.people},
        synced_at: at
      })

    Repo.insert_all(
      Building,
      for(
        {slot, type, lv} <- Historic.captured_buildings(),
        do: %{city_id: city.id, slot: slot, type: type, level: lv}
      )
    )

    resnapshot(Repo.get!(City, city.id), at)
  end

  # Medals go to the player the moment the battle is won (not when the march gets home). The player is locked after
  # the city, as research does.
  defp add_medals(player_id, more) do
    medals = Repo.one!(from p in Player, where: p.id == ^player_id, lock: "FOR UPDATE", select: p.medals)
    Repo.update_all(from(p in Player, where: p.id == ^player_id), set: [medals: Titles.add(medals, more)])
  end

  # The NPC (or lord's town or historic city) at x, y as it stands at at_ms, locked for this transaction, and its
  # npc_states row. full is what it holds when full, periods how fast it refills (Age3.Npc.current/4); daily? makes
  # it full again once a daily reset has passed since its last battle (historic cities). One never attacked gets
  # its row now (full, as of at_ms), so there is always a row to lock.
  defp lock_npc(x, y, level, full, at_ms, periods, daily?) do
    Repo.insert_all(
      NpcState,
      [
        %{
          x: x,
          y: y,
          level: level,
          troops: full["troops"],
          forts: full["forts"],
          resources: full["resources"],
          updated_at: to_datetime(at_ms)
        }
      ],
      on_conflict: :nothing,
      conflict_target: [:x, :y]
    )

    s = Repo.one!(from n in NpcState, where: n.x == ^x and n.y == ^y, lock: "FOR UPDATE")
    saved_ms = to_ms(s.updated_at)

    npc =
      if daily? and Historic.day(saved_ms) < Historic.day(at_ms) do
        full
      else
        saved = %{troops: s.troops, forts: s.forts, resources: s.resources, updated_at_ms: saved_ms}
        Npc.current(saved, full, at_ms, periods)
      end

    {npc, s}
  end

  # The player's research (capped in this city) as the battle engine's technology.
  defp combat_tech(research) do
    lv = &Research.level_of(research, &1)

    %{
      military_tradition: lv.("militaryTradition"),
      iron_working: lv.("ironWorking"),
      compass: lv.("compass"),
      horseback_riding: lv.("horsebackRiding"),
      archery: lv.("archery"),
      medicine: lv.("medicine"),
      engineering: lv.("engineering"),
      machinery: lv.("machinery")
    }
  end

  defp combat_hero(nil), do: Combat.default_army().hero

  defp combat_hero(h),
    do: %{level: h.level, attack: h.attack, intelligence: h.intelligence, leadership: h.level, stars: h.stars}

  # A player battle's honor for both sides (Age3.Honor); battles with NPCs change none. Prestige isn't earned
  # yet (TJ is reworking it).
  defp battle_points(_att_player, nil, _result), do: :ok

  defp battle_points(att_player, def_player, result) do
    {att_lost, def_lost} = Honor.losses(result)
    add_honor(att_player, Honor.change(att_lost, def_lost))
    add_honor(def_player, Honor.change(def_lost, att_lost))
  end

  defp add_honor(_player_id, 0), do: :ok

  defp add_honor(player_id, honor) do
    Repo.update_all(
      from(p in Player,
        where: p.id == ^player_id,
        update: [set: [honor: fragment("greatest(0, ? + ?)", p.honor, ^honor)]]
      ),
      []
    )
  end

  # Gives the hero exp and returns what the report shows about them.
  defp gain_hero_exp(hero, exp) do
    up = Heroes.gain_exp(hero, exp)
    hero |> Ecto.Changeset.change(level: up.level, exp: up.exp, points: up.points) |> Repo.update!()
    %{"name" => hero.name, "exp" => exp, "level" => up.level, "levelsGained" => up.level - hero.level}
  end

  # Inside a transaction holding the city's lock. Settles the resources, population and loyalty up to `at` at the
  # rates the city had (city is the row as it was before the change), then saves them with the rates, caps and
  # population limit its buildings, troops, tax rate and people give now. `changes` are other City fields to save
  # with it, e.g. tax_rate: 20.
  defp resnapshot(city, at, changes \\ []) do
    # never move the snapshot back in time
    synced_at = Enum.max([city.synced_at, at], DateTime)
    %{resources: resources, population: population, loyalty: loyalty} = settled(city, to_ms(synced_at))
    tax_rate = Keyword.get(changes, :tax_rate, city.tax_rate)
    buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
    # read again: a training batch that just finished changed them
    troops = Repo.one!(from c in City, where: c.id == ^city.id, select: c.troops)
    max = Economy.max_population(buildings)
    current = min(population["current"], max)
    people = %{"current" => current, "max" => max, "idle" => current}

    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set:
        Keyword.merge(
          [
            resources:
              Economy.recalc(
                resources,
                buildings,
                tax_rate,
                research_of(city.player_id),
                fed_troops(city.id, troops),
                salary_of(city.id),
                people,
                production_bonus(city.id)
              ),
            population: people,
            loyalty: loyalty,
            synced_at: synced_at
          ],
          changes
        )
    )
  end

  # More production (%) per resource for a city, on top of research: its valleys (Age3.Valley.bonuses/1) and its
  # mayor's Politics (+1% of the fields' production per point, wiki: Stats).
  defp production_bonus(city_id) do
    valleys =
      Repo.all(
        from v in ValleyHold, where: v.city_id == ^city_id, select: %{terrain: v.terrain, level: v.level}
      )

    mayor = Repo.one(from h in Hero, where: h.city_id == ^city_id and h.status == "mayor", select: h.politics)

    Map.merge(Valley.bonuses(valleys), Heroes.politics_bonus(mayor), fn _k, a, b -> a + b end)
  end

  # The city as it stands at at_ms (%{resources, population, loyalty}), worked out from its snapshot.
  defp settled(city, at_ms), do: Economy.settle_city(city, to_ms(city.synced_at), at_ms)

  # A city saved before its rates came from buildings (or before the data file changed, or before a research
  # finished in another city) still has the old rates, caps or population limit. Gives it the right ones from now
  # on.
  defp refresh_stale(city_id, now) do
    city = City |> Repo.get!(city_id) |> Repo.preload(:buildings)

    stale? =
      Economy.recalc(
        city.resources,
        city.buildings,
        city.tax_rate,
        research_of(city.player_id),
        fed_troops(city.id, city.troops),
        salary_of(city.id),
        city.population,
        production_bonus(city.id)
      ) != city.resources or
        Economy.max_population(city.buildings) != city.population["max"]

    if stale? do
      Repo.transaction(fn ->
        Repo.one(from c in City, where: c.id == ^city_id, lock: "FOR UPDATE", select: c.id)
        resnapshot(Repo.get!(City, city_id), now)
      end)
    end
  end

  defp lock_city(player_id, city_id) do
    case Ecto.UUID.cast(city_id) do
      {:ok, id} ->
        Repo.one(from c in City, where: c.id == ^id and c.player_id == ^player_id, lock: "FOR UPDATE")

      :error ->
        nil
    end
  end

  # A new snapshot: the settled amounts as of now, which is where Economy.settle_city starts next time. The
  # population and loyalty share the snapshot's time, so they are settled to now too, less the `people` that just
  # went into training (negative to give them back). Fewer people pay less tax, so the gold rate follows them.
  defp save_resources(city, resources, now_ms, people \\ 0) do
    %{population: settled_pop, loyalty: loyalty} = settled(city, now_ms)
    population = Economy.take_population(settled_pop, people)

    resources =
      update_in(resources, ["gold", "perHour"], fn rate ->
        rate - Loyalty.tax_gold(settled_pop, city.tax_rate) + Loyalty.tax_gold(population, city.tax_rate)
      end)

    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set: [resources: resources, population: population, loyalty: loyalty, synced_at: to_datetime(now_ms)]
    )
  end

  # Times are epoch milliseconds in messages and microseconds (timestamptz) in the database.
  defp to_datetime(ms), do: DateTime.from_unix!(ms * 1000, :microsecond)
  defp to_ms(datetime), do: DateTime.to_unix(datetime, :millisecond)

  # The JSON shapes match packages/core/src/types, so the client can use them as-is.

  defp player_json(p) do
    %{
      id: p.id,
      name: p.name,
      title: Titles.name(:title, p.title),
      titleId: p.title,
      militaryRank: Titles.name(:rank, p.military_rank),
      rankId: p.military_rank,
      medals: p.medals,
      cityCap: Titles.city_cap(p.title),
      alliance: p.alliance,
      prestige: p.prestige,
      honor: p.honor,
      research: p.research,
      instantMarch: p.instant_march,
      unreadReports: unread_reports(p.id),
      unreadMail: Social.unread(p.id),
      items: p.items || %{},
      allianceRank: p.alliance_rank,
      # the player's place by prestige (backlog 2: derived, never stored)
      rank: Repo.aggregate(from(o in Player, where: o.prestige > ^p.prestige), :count) + 1
    }
  end

  # Resources are settled to now_ms on the way out; the stored snapshot only changes when something spends.
  # Town buildings and outskirts fields share the buildings table; fields have slots "f0".."f12".
  defp city_json(c, tasks, now_ms) do
    now = settled(c, now_ms)
    busy = for t <- tasks, t.city_id == c.id and t.kind == "build", into: MapSet.new(), do: t.slot
    {fields, town} = Enum.split_with(c.buildings, &String.starts_with?(&1.slot, "f"))

    %{
      id: c.id,
      name: c.name,
      x: c.x,
      y: c.y,
      level: c.level,
      resources: now.resources,
      population: now.population,
      loyalty: now.loyalty,
      grievance: c.grievance,
      gateOpen: c.gate_open,
      defenderHeroId: c.defender_hero_id,
      taxRate: c.tax_rate,
      comfortAt: c.comfort_at && to_ms(c.comfort_at),
      levyAt: c.levy_at && to_ms(c.levy_at),
      historicLevel: c.historic_level,
      policiesLeft:
        c.historic_level && Historic.policies_left(c.historic_level, c.policies_used, c.policies_day, now_ms),
      buildings: Enum.map(town, &building_json(&1, busy)),
      fields: Enum.map(fields, &building_json(&1, busy)),
      troops: c.troops,
      forts: c.forts || %{},
      allowGarrison: c.allow_garrison,
      valleys:
        for(
          v <- Repo.all(from v in ValleyHold, where: v.city_id == ^c.id, order_by: [v.y, v.x]),
          do: %{x: v.x, y: v.y, level: v.level, terrain: v.terrain}
        ),
      garrisons:
        for(
          t <- stationed_in(c.id),
          do: %{taskId: t.id, cityId: t.city_id, troops: t.data["troops"], owner: owner_name(t.city_id)}
        ),
      heroes: Enum.map(c.heroes, &hero_json/1),
      inn: inn_json(c.inn),
      incoming: incoming(c)
    }
  end

  # Other lords' marches on their way to this city, as far as its Beacon Tower sees them (Age3.Beacon).
  defp incoming(c) do
    level = Build.level_of(c.buildings, "beacontower")

    if level < 1 do
      []
    else
      Repo.all(
        from t in Task,
          join: src in City,
          on: src.id == t.city_id,
          join: p in Player,
          on: p.id == src.player_id,
          where:
            t.kind == "march" and t.target_city_id == ^c.id and src.player_id != ^c.player_id and
              fragment("?->>'phase' = 'out'", t.data),
          order_by: t.ends_at,
          select: {t, src, p}
      )
      |> Enum.map(fn {t, src, p} ->
        hero = t.data["heroId"] && Repo.get(Hero, t.data["heroId"])

        Beacon.seen(level, %{
          id: t.id,
          mission: t.data["mission"] || "attack",
          arrives_at: to_ms(t.ends_at),
          lord: p.name,
          from: %{x: src.x, y: src.y, name: src.name},
          troops: t.data["troops"],
          hero_level: hero && hero.level,
          research: p.research || %{}
        })
      end)
    end
  end

  defp owner_name(city_id),
    do:
      Repo.one(
        from c in City, join: p in Player, on: p.id == c.player_id, where: c.id == ^city_id, select: p.name
      )

  defp hero_json(h) do
    %{
      id: h.id,
      name: h.name,
      level: h.level,
      leadership: h.level,
      exp: h.exp,
      expToNext: Heroes.exp_to_next(h.level),
      points: h.points,
      politics: h.politics,
      attack: h.attack,
      intelligence: h.intelligence,
      stars: h.stars,
      status: h.status,
      salary: Heroes.salary(h.level)
    }
  end

  # fee and salary are worked out here so the client never repeats the formulas
  defp inn_json(%{"refreshAt" => refresh_at, "offers" => offers}) do
    %{
      refreshAt: refresh_at,
      offers:
        Enum.map(offers, fn o ->
          %{
            id: o["id"],
            name: o["name"],
            level: o["level"],
            politics: o["politics"],
            attack: o["attack"],
            intelligence: o["intelligence"],
            fee: Heroes.fee(o["level"]),
            salary: Heroes.salary(o["level"])
          }
        end)
    }
  end

  defp inn_json(_none), do: nil

  defp building_json(b, busy) do
    json = %{type: b.type, level: b.level, slot: slot_json(b.slot)}
    if MapSet.member?(busy, b.slot), do: Map.put(json, :upgrading, true), else: json
  end

  defp task_json(t) do
    %{
      id: t.id,
      cityId: t.city_id,
      kind: t.kind,
      label: t.label,
      startedAt: to_ms(t.started_at),
      endsAt: to_ms(t.ends_at),
      slot: t.slot,
      targetType: t.target_type,
      targetLevel: t.target_level
    }
    |> then(&if(t.kind == "march", do: Map.put(&1, :march, march_json(t.data)), else: &1))
  end

  defp march_json(d) do
    %{
      phase: d["phase"],
      x: d["x"],
      y: d["y"],
      heroId: d["heroId"],
      heroName: d["heroName"],
      troops: d["troops"],
      loot: d["loot"] || %{},
      seconds: d["seconds"],
      camp: d["camp"] || 0,
      mission: d["mission"] || "attack",
      cargo: d["cargo"] || %{},
      hostName: d["hostName"],
      medals: d["medals"] || %{},
      won: d["won"],
      reportId: d["reportId"]
    }
  end

  defp report_json(r) do
    %{
      id: r.id,
      cityId: r.city_id,
      title: r.title,
      x: r.x,
      y: r.y,
      won: r.won,
      loot: r.loot,
      medals: r.medals || %{},
      side: r.side,
      loyalty: r.loyalty,
      policy: r.policy,
      scout: r.scout,
      kind: r.kind || "battle",
      hero: r.hero,
      read: r.read,
      foughtAt: to_ms(r.fought_at)
    }
  end

  # Town plots and fields go to the client as numbers, the Town Hall and walls as names.
  defp slot_json("f" <> n), do: String.to_integer(n)

  defp slot_json(slot) do
    case Integer.parse(slot) do
      {n, ""} -> n
      _ -> slot
    end
  end
end
