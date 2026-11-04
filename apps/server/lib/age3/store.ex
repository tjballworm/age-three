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
  Sends an attack from one of the player's cities to the NPC city at x, y with hero_id and troops
  (%{"warrior" => 100}), taking the troops, hero and the trip's food now (Age3.March). Returns when it arrives.
  """
  @callback march(
              player_id :: String.t(),
              city_id :: String.t(),
              x :: integer,
              y :: integer,
              hero_id :: String.t(),
              troops :: map,
              now_ms :: integer
            ) :: {:ok, ends_at_ms :: integer} | {:error, code :: String.t()}

  @doc "Turns a march that hasn't arrived yet around; it takes as long to come back as it has been out."
  @callback recall(player_id :: String.t(), city_id :: String.t(), task_id :: String.t(), now_ms :: integer) ::
              {:ok, ends_at_ms :: integer} | {:error, code :: String.t()}

  @doc "The player's latest battle reports, newest first, without the battle details."
  @callback reports(player_id :: String.t()) :: [map]

  @doc "One of the player's battle reports with the whole battle (BattleResult), marking it read."
  @callback report(player_id :: String.t(), report_id :: String.t()) ::
              {:ok, map} | {:error, code :: String.t()}

  @doc "Stops a construction that hasn't finished and refunds its whole cost."
  @callback cancel_build(
              player_id :: String.t(),
              city_id :: String.t(),
              task_id :: String.t(),
              now_ms :: integer
            ) ::
              :ok | {:error, code :: String.t()}
end

defmodule Age3.Store.Pg do
  # The real store, on Postgres through Ecto.
  @moduledoc false
  @behaviour Age3.Store

  import Ecto.Query

  alias Age3.{
    Accounts,
    Build,
    Building,
    Cheats,
    City,
    Combat,
    Data,
    Economy,
    Game,
    Hero,
    Heroes,
    Lord,
    Loyalty,
    March,
    Npc,
    NpcState,
    Player,
    Pvp,
    Report,
    Repo,
    Research,
    Task,
    Titles,
    Train,
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

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "build",
            label: "#{Data.building(plan.type)["name"]} → Lv #{plan.level}",
            slot: slot,
            target_type: plan.type,
            target_level: plan.level,
            cost: plan.cost,
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

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "research",
            label: "#{Data.tech(tech)["name"]} → Lv #{plan.level}",
            target_type: tech,
            target_level: plan.level,
            cost: plan.cost,
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

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "train",
            label: "#{count} × #{Data.troop(troop)["name"]}",
            slot: slot,
            target_type: troop,
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
      if kind == "train", do: rechain(city.id, task.slot, now_ms)
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
      limit = pop["max"]

      case Loyalty.check_comfort(
             kind,
             comfort_at,
             now_ms,
             limit,
             get_in(resources, [kind_resource(kind), "amount"]) || 0
           ) do
        {:ok, c} ->
          {loyalty, grievance} = Loyalty.apply_change(loyalty, city.grievance, c.loyalty, c.grievance)
          save_resources(city, Build.spend(resources, %{c.resource => c.cost}), now_ms)

          Repo.update_all(from(x in City, where: x.id == ^city.id),
            set: [loyalty: loyalty, grievance: grievance, comfort_at: now]
          )

        {:error, code} ->
          Repo.rollback(code)
      end
    end)
    |> ok()
  end

  defp kind_resource("relief"), do: "food"
  defp kind_resource(_kind), do: "gold"

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
          alliance: p.alliance
        }
    )
  end

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

  @impl true
  def march(player_id, city_id, x, y, hero_id, troops, now_ms) do
    now = to_datetime(now_ms)
    arrivals([city_id], now)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      player = Repo.get!(Player, player_id)
      research = Research.in_city(player.research, buildings)
      hero = find_hero(city.id, hero_id)
      resources = settled(city, now_ms).resources
      food = resources["food"]["amount"]

      target = Pvp.target(city_at(x, y), World.tile_at(x, y), player_id)

      case March.check(buildings, research, city.troops, hero, {city.x, city.y}, {x, y}, food, troops, target) do
        {:ok, plan} ->
          seconds = if player.instant_march, do: 1, else: plan.seconds
          save_resources(city, Build.spend(resources, %{"food" => plan.food}), now_ms)

          Repo.update_all(from(c in City, where: c.id == ^city.id),
            set: [troops: March.take(city.troops, plan.troops)]
          )

          Repo.update_all(from(h in Hero, where: h.id == ^hero.id), set: [status: "marching"])
          # fewer troops at home eat less food
          resnapshot(Repo.get!(City, city.id), now)

          Repo.insert!(%Task{
            city_id: city.id,
            kind: "march",
            label: attack_label(target, x, y),
            target_type: "attack",
            target_level: plan.level || elem(target, 1).level,
            target_city_id: with({:city, c} <- target, do: c.id, else: (_ -> nil)),
            cost: %{"food" => plan.food},
            data: %{
              "phase" => "out",
              "x" => x,
              "y" => y,
              "heroId" => hero.id,
              "heroName" => hero.name,
              "troops" => plan.troops,
              "seconds" => seconds,
              "target" => Atom.to_string(elem(target, 0))
            },
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

  defp attack_label({:city, c}, x, y), do: "Attack on #{c.name} (#{x},#{y})"
  defp attack_label({:npc, level}, x, y), do: "Attack on Lv#{level} NPC (#{x},#{y})"
  defp attack_label({:lord, _level}, x, y), do: "Attack on #{Lord.name(x, y)} (#{x},#{y})"

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
      if task.data["phase"] != "out", do: Repo.rollback("already_returning")
      back_ms = max(1000, now_ms - to_ms(task.started_at))

      task
      |> Ecto.Changeset.change(
        label: "Returning from (#{task.data["x"]},#{task.data["y"]})",
        data: Map.merge(task.data, %{"phase" => "back", "loot" => %{}}),
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

    Repo.update_all(from(t in Task, where: t.city_id == ^city.id), set: [ends_at: now])
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
  defp training_queue(city_id, slot),
    do:
      Repo.all(
        from t in Task,
          where: t.city_id == ^city_id and t.kind == "train" and t.slot == ^slot,
          order_by: t.ends_at
      )

  # How many people a task took: a training batch's troops x their population; nothing for other tasks.
  defp people(%Task{kind: "train", target_type: troop, target_level: count}),
    do: Data.troop(troop)["population"] * count

  defp people(_task), do: 0

  # After a batch was cancelled or sped up: closes the gap in that Barracks' queue. The batch running now keeps
  # its times; each waiting one starts when the one before it ends (or now), keeping its length.
  defp rechain(city_id, slot, now_ms) do
    Enum.reduce(training_queue(city_id, slot), now_ms, fn t, starts_ms ->
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
        {task, players} = attack_city(attacker, Repo.get!(City, t.target_city_id), t)
        Repo.delete!(t)
        resnapshot(Repo.get!(City, attacker.id), t.ends_at)
        {task, attacker.player_id, players}
    end
  end

  # Pushes a player's new state to their open games (none in tests, where nothing is registered).
  defp tell(player_id, reason) do
    if Process.whereis(Age3.Players), do: Age3.Session.notify(player_id, reason)
  end

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

    {defender, forts, settings} =
      Pvp.battle(def.troops, combat_tech(def_research), guard && combat_hero(guard), walls, open?)

    attacker = %{
      Combat.default_army()
      | troops: d["troops"],
        tech: combat_tech(att_research),
        hero: combat_hero(hero),
        heal_percent: 0
    }

    result =
      Combat.simulate(%{attacker: attacker, defender: defender, fortifications: forts, settings: settings})

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
      set: [troops: Pvp.troops_left(def.troops, result, open?)]
    )

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
        applied = apply_task(Repo.get!(City, city_id), t)
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

  defp apply_task(city, %Task{kind: "train"} = t) do
    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set: [troops: Train.add(city.troops, t.target_type, t.target_level)]
    )
  end

  # A march arriving at its NPC (or a made-up lord's town, fought the same way: Age3.Lord): the battle, as at the
  # moment it arrived. The NPC is locked (after the city, as always) so two marches arriving at once fight one
  # after the other. Saves what is left of the NPC, the hero's exp and a report, and sends the survivors home with
  # their loot. Returns the task with the outcome added. Marches sent before lords' towns existed have no "target".
  defp apply_task(city, %Task{kind: "march", data: %{"phase" => "out"} = d} = t) do
    at_ms = to_ms(t.ends_at)
    {x, y, level} = {d["x"], d["y"], t.target_level}
    lord? = d["target"] == "lord"
    full = if lord?, do: Lord.full(x, y, level), else: Npc.full(level)
    what = if lord?, do: Lord.name(x, y), else: "Lv#{level} NPC"
    npc = lock_npc(x, y, level, full, at_ms)
    buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
    research = Research.in_city(research_of(city.player_id), buildings)
    hero = Repo.get(Hero, d["heroId"])
    {defender, forts, settings} = Npc.battle(npc, level)

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

    Repo.update_all(from(n in NpcState, where: n.x == ^x and n.y == ^y),
      set: [troops: left["troops"], forts: left["forts"], resources: left["resources"], updated_at: t.ends_at]
    )

    hero_report = hero && gain_hero_exp(hero, March.hero_exp(result))
    # lords' towns drop no medals
    medals =
      if not lord? and Titles.full_clear?(won, npc, full, result), do: Titles.roll_npc(level), else: %{}

    if medals != %{}, do: add_medals(city.player_id, medals)

    report =
      Repo.insert!(%Report{
        player_id: city.player_id,
        city_id: city.id,
        title: "#{if won, do: "Victory", else: "Defeat"} against #{what} (#{x},#{y})",
        x: x,
        y: y,
        won: won,
        loot: loot,
        medals: medals,
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

  # A march home: the troops rejoin the city, the hero is free again and the loot goes into storage (it can go
  # over the cap, like a cheat's resources).
  defp apply_task(city, %Task{kind: "march", data: %{"phase" => "back"} = d} = t) do
    resnapshot(city, t.ends_at)
    city = Repo.get!(City, city.id)
    resources = Cheats.add_resources(city.resources, d["loot"] || %{})
    troops = Enum.reduce(d["troops"], city.troops, fn {type, n}, acc -> Train.add(acc, type, n) end)
    Repo.update_all(from(c in City, where: c.id == ^city.id), set: [resources: resources, troops: troops])

    Repo.update_all(from(h in Hero, where: h.id == ^d["heroId"] and h.status == "marching"),
      set: [status: "idle"]
    )
  end

  # Medals go to the player the moment the battle is won (not when the march gets home). The player is locked after
  # the city, as research does.
  defp add_medals(player_id, more) do
    medals = Repo.one!(from p in Player, where: p.id == ^player_id, lock: "FOR UPDATE", select: p.medals)
    Repo.update_all(from(p in Player, where: p.id == ^player_id), set: [medals: Titles.add(medals, more)])
  end

  # The NPC (or lord's town) at x, y as it stands at at_ms, locked for this transaction. full is what it holds
  # when full. One never attacked gets its row now (full, as of at_ms), so there is always a row to lock.
  defp lock_npc(x, y, level, full, at_ms) do
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
    saved = %{troops: s.troops, forts: s.forts, resources: s.resources, updated_at_ms: to_ms(s.updated_at)}
    Npc.current(saved, full, at_ms)
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
                troops,
                salary_of(city.id),
                people
              ),
            population: people,
            loyalty: loyalty,
            synced_at: synced_at
          ],
          changes
        )
    )
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
        city.troops,
        salary_of(city.id),
        city.population
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
      # not stored yet; the backlog has it derived from prestige
      rank: 0
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
      buildings: Enum.map(town, &building_json(&1, busy)),
      fields: Enum.map(fields, &building_json(&1, busy)),
      troops: c.troops,
      heroes: Enum.map(c.heroes, &hero_json/1),
      inn: inn_json(c.inn)
    }
  end

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
