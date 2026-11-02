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

  @doc "Finishes a construction now, for free, when it has Data.free_speedup_ms/0 or less left."
  @callback speed_up(player_id :: String.t(), city_id :: String.t(), task_id :: String.t(), now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

  @doc "Sets a city's tax rate (0-100). Gold from taxes changes from now on."
  @callback set_tax(player_id :: String.t(), city_id :: String.t(), tax_rate :: integer, now_ms :: integer) ::
              :ok | {:error, code :: String.t()}

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
  alias Age3.{Accounts, Build, Building, City, Data, Economy, Game, Player, Repo, Task}

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
         %Player{} = player <- Repo.get(Player, player_id) do
      now = to_datetime(now_ms)
      city_ids = Repo.all(from c in City, where: c.player_id == ^player_id, select: c.id)
      Enum.each(city_ids, &finish_due_in_city(&1, now))
      Enum.each(city_ids, &refresh_stale(&1, now))

      buildings = from(b in Building, order_by: b.slot)

      cities =
        Repo.all(
          from c in City, where: c.player_id == ^player_id, order_by: c.id, preload: [buildings: ^buildings]
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

      case Build.check(buildings, resources, slot, type) do
        {:ok, plan} ->
          save_resources(city.id, Build.spend(resources, plan.cost), now)

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
  def cancel_build(player_id, city_id, task_id, now_ms) do
    now = to_datetime(now_ms)

    Repo.transaction(fn ->
      city = lock_city(player_id, city_id) || Repo.rollback("bad_message")

      # a build that has already finished can't be cancelled, and finishing one changes the city, so read it again
      city = if complete_due(city.id, now) == [], do: city, else: Repo.get!(City, city.id)
      task = build_task(city.id, task_id) || Repo.rollback("bad_message")
      resources = Economy.settle(city.resources, to_ms(city.synced_at), now_ms)
      save_resources(city.id, Build.spend(resources, task.cost, -1), now)
      Repo.delete!(task)
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
      task = build_task(city.id, task_id) || Repo.rollback("bad_message")

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

  defp build_task(city_id, task_id) do
    case Ecto.UUID.cast(task_id) do
      {:ok, id} ->
        Repo.one(from t in Task, where: t.id == ^id and t.city_id == ^city_id and t.kind == "build")

      :error ->
        nil
    end
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

  # Inside a transaction holding the city's lock: applies each finished build to its building and drops the task.
  # Production changes the moment a building finishes, so resources are settled up to that moment at the old
  # rates and saved as a new snapshot with the new rates and population.
  defp complete_due(city_id, now) do
    tasks = Repo.all(from t in Task, where: t.city_id == ^city_id and t.ends_at <= ^now, order_by: t.ends_at)

    for t <- tasks do
      city = Repo.get!(City, city_id)

      Repo.insert!(%Building{city_id: city_id, slot: t.slot, type: t.target_type, level: t.target_level},
        on_conflict: [set: [type: t.target_type, level: t.target_level]],
        conflict_target: [:city_id, :slot]
      )

      Repo.delete!(t)
      resnapshot(city, t.ends_at)
    end

    tasks
  end

  # Inside a transaction holding the city's lock. Settles the resources up to `at` at the rates the city had
  # (city is the row as it was before the change), then saves them with the rates, caps and population its
  # buildings and tax rate give now. `changes` are other City fields to save with it, e.g. tax_rate: 20.
  defp resnapshot(city, at, changes \\ []) do
    # never move the snapshot back in time
    synced_at = Enum.max([city.synced_at, at], DateTime)
    resources = Economy.settle(city.resources, to_ms(city.synced_at), to_ms(synced_at))
    tax_rate = Keyword.get(changes, :tax_rate, city.tax_rate)
    buildings = Repo.all(from b in Building, where: b.city_id == ^city.id)

    Repo.update_all(from(c in City, where: c.id == ^city.id),
      set:
        [
          resources: Economy.recalc(resources, buildings, tax_rate),
          population: Economy.population(buildings),
          synced_at: synced_at
        ] ++ changes
    )
  end

  # A city saved before its rates came from buildings (or before the data file changed) still has the old
  # rates, caps or population. Gives it the right ones from now on.
  defp refresh_stale(city_id, now) do
    city = City |> Repo.get!(city_id) |> Repo.preload(:buildings)

    stale? =
      Economy.recalc(city.resources, city.buildings, city.tax_rate) != city.resources or
        Economy.population(city.buildings) != city.population

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

  # A new snapshot: the settled amounts as of now, which is where Economy.settle starts next time.
  defp save_resources(city_id, resources, now) do
    Repo.update_all(from(c in City, where: c.id == ^city_id), set: [resources: resources, synced_at: now])
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
      # not stored yet; the backlog has it derived from prestige
      rank: 0
    }
  end

  # Resources are settled to now_ms on the way out; the stored snapshot only changes when something spends.
  # Town buildings and outskirts fields share the buildings table; fields have slots "f0".."f12".
  defp city_json(c, tasks, now_ms) do
    since_ms = to_ms(c.synced_at)
    busy = for t <- tasks, t.city_id == c.id, into: MapSet.new(), do: t.slot
    {fields, town} = Enum.split_with(c.buildings, &String.starts_with?(&1.slot, "f"))

    %{
      id: c.id,
      name: c.name,
      x: c.x,
      y: c.y,
      level: c.level,
      resources: Economy.settle(c.resources, since_ms, now_ms),
      population: c.population,
      loyalty: c.loyalty,
      taxRate: c.tax_rate,
      buildings: Enum.map(town, &building_json(&1, busy)),
      fields: Enum.map(fields, &building_json(&1, busy))
    }
  end

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
