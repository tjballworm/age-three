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
  Finishes a construction, research or the training batch a Barracks is working on now, for free, when it has
  Data.free_speedup_ms/0 or less left.
  """
  @callback speed_up(player_id :: String.t(), city_id :: String.t(), task_id :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

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
    March,
    Npc,
    NpcState,
    Player,
    Report,
    Repo,
    Research,
    Task,
    Train
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

      case place_city(player.id, name, 50) do
        {:ok, city} ->
          Repo.insert_all(Building, [
            %{city_id: city.id, slot: "townhall", type: "townhall", level: 1},
            %{city_id: city.id, slot: "walls", type: "walls", level: 1}
          ])

          player.id

        :error ->
          Repo.rollback("no free map spot for #{inspect(name)}")
      end
    end)
  end

  # A random free spot; the unique (x, y) constraint settles any race.
  defp place_city(_player_id, _name, 0), do: :error

  defp place_city(player_id, name, tries) do
    x = :rand.uniform(Game.world_size()) - 1
    y = :rand.uniform(Game.world_size()) - 1

    if Game.historic_city?(x, y) do
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
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      # finishing a build changes the city's resources and rates, so read it again afterwards
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)

      if Repo.exists?(from t in Task, where: t.city_id == ^city.id and t.kind == "build"),
        do: Repo.rollback("queue_busy")

      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      resources = Economy.settle(city.resources, to_ms(city.synced_at), now_ms)

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
      resources = Economy.settle(city.resources, to_ms(city.synced_at), now_ms)

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
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)

      # a Barracks keeps training while it is upgraded; its queue size and the troops it unlocks come from the
      # level it has now
      queue = training_queue(city.id, slot)
      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      since_ms = to_ms(city.synced_at)
      resources = Economy.settle(city.resources, since_ms, now_ms)
      idle = Economy.settle_population(city.population, city.tax_rate, since_ms, now_ms)["idle"]

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
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")

      # a task that has already finished can't be cancelled, and finishing one changes the city, so read it again
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      task = find_task(city.id, task_id, [kind]) || Repo.rollback("bad_message")
      resources = Economy.settle(city.resources, to_ms(city.synced_at), now_ms)
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
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      complete_due(city.id, now)
      task = find_task(city.id, task_id, ["build", "research", "train"]) || Repo.rollback("bad_message")

      # a training batch still waiting its turn isn't in its last 5 minutes, however short it is
      if to_ms(task.ends_at) - now_ms > Data.free_speedup_ms() or
           DateTime.compare(task.started_at, now) == :gt,
         do: Repo.rollback("too_early")

      # finish it as if it had ended now; the next batch in that Barracks starts now
      task |> Ecto.Changeset.change(ends_at: now) |> Repo.update!()
      complete_due(city.id, now)
      if task.kind == "train", do: rechain(city.id, task.slot, now_ms)
    end)
    |> case do
      {:ok, _done} -> :ok
      {:error, code} -> {:error, code}
    end
  end

  @impl true
  def set_tax(player_id, city_id, tax_rate, now_ms) do
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
      resources = Economy.settle(city.resources, to_ms(city.synced_at), now_ms)

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
  def dismiss(player_id, city_id, hero_id, now_ms) do
    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      hero = find_hero(city.id, hero_id) || Repo.rollback("bad_message")
      if hero.status != "idle", do: Repo.rollback("hero_busy")
      Repo.delete!(hero)
      resnapshot(city, to_datetime(now_ms))
    end)
    |> ok()
  end

  @impl true
  def set_mayor(player_id, city_id, hero_id, _now_ms) do
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

  defp salary_of(city_id),
    do: Heroes.salaries(Repo.all(from h in Hero, where: h.city_id == ^city_id, select: %{level: h.level}))

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

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
      player = Repo.get!(Player, player_id)
      research = Research.in_city(player.research, buildings)
      hero = find_hero(city.id, hero_id)
      resources = Economy.settle(city.resources, to_ms(city.synced_at), now_ms)
      food = resources["food"]["amount"]

      case March.check(buildings, research, city.troops, hero, {city.x, city.y}, {x, y}, food, troops) do
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
            label: "Attack on Lv#{plan.level} NPC (#{x},#{y})",
            target_type: "attack",
            target_level: plan.level,
            cost: %{"food" => plan.food},
            data: %{
              "phase" => "out",
              "x" => x,
              "y" => y,
              "heroId" => hero.id,
              "heroName" => hero.name,
              "troops" => plan.troops,
              "seconds" => seconds
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

  @impl true
  def recall(player_id, city_id, task_id, now_ms) do
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
            select: struct(r, [:id, :city_id, :title, :x, :y, :won, :loot, :hero, :read, :fought_at])
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

  # Cheats (testing commands). Locks the target cities in id order and then the player, like research does, so
  # they can't deadlock with other commands. Anything already due finishes first.

  @impl true
  def cheat(player_id, target, action, args, now_ms) do
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      {target_id, city_ids} = cheat_target(player_id, target) || Repo.rollback(not_found(target))

      Repo.all(from c in City, where: c.id in ^city_ids, order_by: c.id, lock: "FOR UPDATE", select: c.id)
      Enum.each(city_ids, &complete_due(&1, now))

      cond do
        action == "instantMarch" ->
          Repo.update_all(from(p in Player, where: p.id == ^target_id), set: [instant_march: args.on])

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
    resources = Economy.settle(city.resources, to_ms(city.synced_at), now_ms)
    save_resources(city, Cheats.add_resources(resources, amounts), now_ms)
  end

  defp cheat_city(city, "fillResources", _args, now_ms) do
    resources = Economy.settle(city.resources, to_ms(city.synced_at), now_ms)
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
    since_ms = to_ms(city.synced_at)
    resources = Economy.settle(city.resources, since_ms, now_ms)
    pop = Economy.settle_population(city.population, city.tax_rate, since_ms, now_ms)
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

  defp cheat_city(city, "heroExp", %{amount: amount}, _now_ms) do
    for h <- Repo.all(from h in Hero, where: h.city_id == ^city.id) do
      up = Heroes.gain_exp(h, amount)
      h |> Ecto.Changeset.change(level: up.level, exp: up.exp, points: up.points) |> Repo.update!()
    end

    :ok
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

    Repo.all(
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
    end)
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
    tasks = Repo.all(from t in Task, where: t.city_id == ^city_id and t.ends_at <= ^now, order_by: t.ends_at)

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

  # A march arriving at its NPC: the battle, as at the moment it arrived. The NPC is locked (after the city, as
  # always) so two marches arriving at once fight one after the other. Saves what is left of the NPC, the hero's
  # exp and a report, and sends the survivors home with their loot. Returns the task with the outcome added.
  defp apply_task(city, %Task{kind: "march", data: %{"phase" => "out"} = d} = t) do
    at_ms = to_ms(t.ends_at)
    {x, y, level} = {d["x"], d["y"], t.target_level}
    npc = lock_npc(x, y, level, at_ms)
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

    report =
      Repo.insert!(%Report{
        player_id: city.player_id,
        city_id: city.id,
        title: "#{if won, do: "Victory", else: "Defeat"} against Lv#{level} NPC (#{x},#{y})",
        x: x,
        y: y,
        won: won,
        loot: loot,
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

    %{t | data: Map.merge(d, %{"won" => won, "reportId" => report.id, "loot" => loot})}
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

  # The NPC at x, y as it stands at at_ms, locked for this transaction. An NPC never attacked gets its row now
  # (full, as of at_ms), so there is always a row to lock.
  defp lock_npc(x, y, level, at_ms) do
    full = Npc.full(level)

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
    Npc.current(saved, level, at_ms)
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
    do: %{level: h.level, attack: h.attack, intelligence: h.intelligence, leadership: h.level, stars: 0}

  # Gives the hero exp and returns what the report shows about them.
  defp gain_hero_exp(hero, exp) do
    up = Heroes.gain_exp(hero, exp)
    hero |> Ecto.Changeset.change(level: up.level, exp: up.exp, points: up.points) |> Repo.update!()
    %{"name" => hero.name, "exp" => exp, "level" => up.level, "levelsGained" => up.level - hero.level}
  end

  # Inside a transaction holding the city's lock. Settles the resources up to `at` at the rates the city had
  # (city is the row as it was before the change), and the population too, then saves them with the rates, caps
  # and population limit its buildings, troops and tax rate give now. `changes` are other City fields to save
  # with it, e.g. tax_rate: 20.
  defp resnapshot(city, at, changes \\ []) do
    # never move the snapshot back in time
    synced_at = Enum.max([city.synced_at, at], DateTime)
    {since_ms, at_ms} = {to_ms(city.synced_at), to_ms(synced_at)}
    resources = Economy.settle(city.resources, since_ms, at_ms)
    population = Economy.settle_population(city.population, city.tax_rate, since_ms, at_ms)
    tax_rate = Keyword.get(changes, :tax_rate, city.tax_rate)
    buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)
    # read again: a training batch that just finished changed them
    troops = Repo.one!(from c in City, where: c.id == ^city.id, select: c.troops)
    max = Economy.max_population(buildings)
    current = min(population["current"], max)

    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set:
        [
          resources:
            Economy.recalc(
              resources,
              buildings,
              tax_rate,
              research_of(city.player_id),
              troops,
              salary_of(city.id)
            ),
          population: %{"current" => current, "max" => max, "idle" => current},
          synced_at: synced_at
        ] ++ changes
    )
  end

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
        salary_of(city.id)
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

  # A new snapshot: the settled amounts as of now, which is where Economy.settle starts next time. The population
  # shares the snapshot's time, so it is settled to now too, less the `people` that just went into training
  # (negative to give them back).
  defp save_resources(city, resources, now_ms, people \\ 0) do
    population =
      city.population
      |> Economy.settle_population(city.tax_rate, to_ms(city.synced_at), now_ms)
      |> Economy.take_population(people)

    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set: [resources: resources, population: population, synced_at: to_datetime(now_ms)]
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
      title: p.title,
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
    since_ms = to_ms(c.synced_at)
    busy = for t <- tasks, t.city_id == c.id and t.kind == "build", into: MapSet.new(), do: t.slot
    {fields, town} = Enum.split_with(c.buildings, &String.starts_with?(&1.slot, "f"))

    %{
      id: c.id,
      name: c.name,
      x: c.x,
      y: c.y,
      level: c.level,
      resources: Economy.settle(c.resources, since_ms, now_ms),
      population: Economy.settle_population(c.population, c.tax_rate, since_ms, now_ms),
      loyalty: c.loyalty,
      taxRate: c.tax_rate,
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
