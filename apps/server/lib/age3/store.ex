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

  @doc "The player and all their cities with buildings, shaped as the client's JSON, resources as at now_ms."
  @callback state(player_id :: String.t(), now_ms :: integer) ::
              {:ok, player :: map, cities :: [map]} | {:error, :not_found}
end

defmodule Age3.Store.Pg do
  # The real store, on Postgres through Ecto.
  @moduledoc false
  @behaviour Age3.Store

  import Ecto.Query
  alias Age3.{Accounts, Building, City, Economy, Game, Player, Repo}

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
      buildings = from(b in Building, order_by: b.slot)

      cities =
        Repo.all(
          from c in City, where: c.player_id == ^player_id, order_by: c.id, preload: [buildings: ^buildings]
        )

      {:ok, player_json(player), Enum.map(cities, &city_json(&1, now_ms))}
    else
      _ -> {:error, :not_found}
    end
  end

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
  defp city_json(c, now_ms) do
    since_ms = DateTime.to_unix(c.synced_at, :millisecond)

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
      buildings: Enum.map(c.buildings, &building_json/1)
    }
  end

  defp building_json(b) do
    json = %{type: b.type, level: b.level, slot: slot_json(b.slot)}
    if b.upgrading, do: Map.put(json, :upgrading, true), else: json
  end

  # plots go to the client as numbers, the Town Hall and walls as names
  defp slot_json(slot) do
    case Integer.parse(slot) do
      {n, ""} -> n
      _ -> slot
    end
  end
end
