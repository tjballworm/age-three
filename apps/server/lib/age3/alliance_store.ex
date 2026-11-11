defmodule Age3.AllianceStore do
  # Alliances against Postgres (rules in Age3.Alliances). Age3.Store.Pg's alliance callbacks call these; founding
  # one is done there, since it pays from a city. Each change runs in a transaction that locks the player's row
  # (and the alliance's members when it changes them), so two officers clicking at once can't both accept the
  # 101st member.
  @moduledoc false

  import Ecto.Query

  alias Age3.{Alliance, AllianceRequest, Alliances, Building, City, Player, Repo}

  @list_size 50

  @doc "What the Alliance window shows a player: their alliance (or nil), invitations and applications, the list."
  def info(player_id) do
    me = Repo.get!(Player, player_id)
    alliance = me.alliance_id && Repo.get(Alliance, me.alliance_id)

    %{
      alliance: alliance && alliance_json(alliance, me),
      invites: requests(me.id, "invite"),
      applied: requests(me.id, "apply"),
      embassy: embassy(me.id),
      alliances: list()
    }
  end

  defp alliance_json(a, me) do
    members =
      Repo.all(
        from p in Player,
          where: p.alliance_id == ^a.id,
          left_join: c in City,
          on: c.player_id == p.id,
          group_by: p.id,
          select: %{
            id: p.id,
            name: p.name,
            rank: p.alliance_rank,
            prestige: p.prestige,
            cities: count(c.id)
          }
      )
      |> Enum.sort_by(&{-Alliances.rank_value(&1.rank), -&1.prestige, &1.name})

    names = alliance_names(Map.keys(a.diplomacy || %{}))

    %{
      id: a.id,
      name: a.name,
      description: a.description,
      rank: me.alliance_rank,
      members: members,
      memberCap: member_cap(a.id),
      diplomacy:
        for(
          {id, status} <- a.diplomacy || %{},
          name = names[id],
          name != nil,
          do: %{id: id, name: name, status: status}
        ),
      applications:
        if(Alliances.can?(me.alliance_rank, :accept),
          do:
            Repo.all(
              from r in AllianceRequest,
                join: p in Player,
                on: p.id == r.player_id,
                where: r.alliance_id == ^a.id and r.kind == "apply",
                order_by: r.inserted_at,
                select: %{id: r.id, player: p.name, prestige: p.prestige}
            ),
          else: []
        )
    }
  end

  defp requests(player_id, kind),
    do:
      Repo.all(
        from r in AllianceRequest,
          join: a in Alliance,
          on: a.id == r.alliance_id,
          where: r.player_id == ^player_id and r.kind == ^kind,
          order_by: r.inserted_at,
          select: %{id: r.id, alliance: a.name}
      )

  defp list do
    Repo.all(
      from a in Alliance,
        left_join: p in Player,
        on: p.alliance_id == a.id,
        group_by: a.id,
        order_by: [desc: count(p.id), asc: a.name],
        limit: @list_size,
        select: %{id: a.id, name: a.name, members: count(p.id), prestige: coalesce(sum(p.prestige), 0)}
    )
    |> Enum.map(fn a -> Map.put(a, :host, host_name(a.id)) end)
  end

  defp host_name(alliance_id),
    do:
      Repo.one(
        from p in Player,
          where: p.alliance_id == ^alliance_id and p.alliance_rank == "host",
          select: p.name,
          limit: 1
      )

  defp alliance_names(ids) do
    ids = for id <- ids, {:ok, id} <- [Ecto.UUID.cast(id)], do: id
    Map.new(Repo.all(from a in Alliance, where: a.id in ^ids, select: {a.id, a.name}))
  end

  @doc "The player's best Embassy level over all their cities (0 without one)."
  def embassy(player_id),
    do:
      Repo.one(
        from b in Building,
          join: c in City,
          on: c.id == b.city_id,
          where: c.player_id == ^player_id and b.type == "embassy",
          select: max(b.level)
      ) || 0

  # 10 per level of the host's best Embassy
  defp member_cap(alliance_id) do
    host =
      Repo.one(
        from p in Player,
          where: p.alliance_id == ^alliance_id and p.alliance_rank == "host",
          select: p.id,
          limit: 1
      )

    Alliances.member_cap(if host, do: embassy(host), else: 1)
  end

  defp member_count(alliance_id),
    do: Repo.aggregate(from(p in Player, where: p.alliance_id == ^alliance_id), :count)

  @doc """
  Makes a new alliance with the player as host, inside the caller's transaction (which has already paid for it).
  Returns the alliance or rolls back with "already_in_alliance", "bad_name" or "name_taken".
  """
  def create(player, name) do
    if player.alliance_id, do: Repo.rollback("already_in_alliance")

    name =
      case Alliances.name(name) do
        {:ok, n} -> n
        {:error, code} -> Repo.rollback(code)
      end

    if Repo.exists?(from a in Alliance, where: fragment("lower(?)", a.name) == ^String.downcase(name)),
      do: Repo.rollback("name_taken")

    alliance = Repo.insert!(%Alliance{name: name})
    enroll(player.id, alliance, "host")
    alliance
  end

  defp enroll(player_id, alliance, rank) do
    Repo.update_all(from(p in Player, where: p.id == ^player_id),
      set: [alliance_id: alliance.id, alliance: alliance.name, alliance_rank: rank]
    )

    # any other applications and invitations are done with
    Repo.delete_all(from r in AllianceRequest, where: r.player_id == ^player_id)
  end

  defp leave_alliance(player_id) do
    Repo.update_all(from(p in Player, where: p.id == ^player_id),
      set: [alliance_id: nil, alliance: nil, alliance_rank: nil]
    )
  end

  @doc """
  One alliance action by a player (anything but founding): "apply" {name}, "cancel" {requestId} (an application),
  "invite" {player}, "accept" / "reject" {requestId} (an application to the player's alliance, or an invitation
  to the player), "leave", "kick" {player}, "setRank" {player, rank} (rank "host" hands the alliance over),
  "diplomacy" {name, status: friendly | neutral | hostile}, "describe" {text}, "disband". Returns :ok or
  {:error, code}.
  """
  def action(player_id, action, args) do
    Repo.transaction(fn ->
      me = Repo.one!(from p in Player, where: p.id == ^player_id, lock: "FOR UPDATE")
      run(me, action, args)
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, code} -> {:error, code}
    end
  end

  defp run(me, "apply", %{"name" => name}) when is_binary(name) do
    if me.alliance_id, do: Repo.rollback("already_in_alliance")
    if embassy(me.id) < 1, do: Repo.rollback("no_embassy")

    alliance =
      Repo.one(from a in Alliance, where: fragment("lower(?)", a.name) == ^String.downcase(String.trim(name))) ||
        Repo.rollback("no_alliance")

    Repo.insert!(%AllianceRequest{alliance_id: alliance.id, player_id: me.id, kind: "apply"},
      on_conflict: :nothing,
      conflict_target: [:alliance_id, :player_id]
    )
  end

  defp run(me, "cancel", %{"requestId" => id}) do
    request = find_request(id) || Repo.rollback("bad_message")
    if request.player_id != me.id or request.kind != "apply", do: Repo.rollback("bad_message")
    Repo.delete!(request)
  end

  defp run(me, "invite", %{"player" => name}) when is_binary(name) do
    allowed!(me, :invite)

    them =
      Repo.one(from p in Player, where: p.name == ^String.trim(name)) || Repo.rollback("player_not_found")

    if them.alliance_id, do: Repo.rollback("already_in_alliance")

    Repo.insert!(%AllianceRequest{alliance_id: me.alliance_id, player_id: them.id, kind: "invite"},
      on_conflict: :nothing,
      conflict_target: [:alliance_id, :player_id]
    )
  end

  defp run(me, "accept", %{"requestId" => id}) do
    request = find_request(id) || Repo.rollback("bad_message")

    case request.kind do
      # an invitation to me
      "invite" when request.player_id == me.id ->
        if me.alliance_id, do: Repo.rollback("already_in_alliance")
        if embassy(me.id) < 1, do: Repo.rollback("no_embassy")
        admit(request.alliance_id, me.id)

      # an application to my alliance
      "apply" when request.alliance_id == me.alliance_id ->
        allowed!(me, :accept)
        them = Repo.one!(from p in Player, where: p.id == ^request.player_id, lock: "FOR UPDATE")
        if them.alliance_id, do: Repo.rollback("already_in_alliance")
        admit(request.alliance_id, them.id)

      _ ->
        Repo.rollback("bad_message")
    end
  end

  defp run(me, "reject", %{"requestId" => id}) do
    request = find_request(id) || Repo.rollback("bad_message")

    cond do
      request.kind == "invite" and request.player_id == me.id -> :ok
      request.kind == "apply" and request.alliance_id == me.alliance_id -> allowed!(me, :accept)
      true -> Repo.rollback("bad_message")
    end

    Repo.delete!(request)
  end

  defp run(me, "leave", _args) do
    if me.alliance_id == nil, do: Repo.rollback("no_alliance")

    if me.alliance_rank == "host" do
      others = members(me.alliance_id) |> Enum.reject(&(&1.id == me.id))

      case Alliances.successor(others) do
        nil ->
          disband(me.alliance_id)

        heir ->
          Repo.update_all(from(p in Player, where: p.id == ^heir.id), set: [alliance_rank: "host"])
          leave_alliance(me.id)
      end
    else
      leave_alliance(me.id)
    end
  end

  defp run(me, "kick", %{"player" => name}) when is_binary(name) do
    allowed!(me, :kick)
    them = member!(me, name)
    if not Alliances.above?(me.alliance_rank, them.alliance_rank), do: Repo.rollback("rank_too_low")
    leave_alliance(them.id)
  end

  defp run(me, "setRank", %{"player" => name, "rank" => "host"}) when is_binary(name) do
    allowed!(me, :host)
    them = member!(me, name)
    if them.id == me.id, do: Repo.rollback("bad_message")
    Repo.update_all(from(p in Player, where: p.id == ^them.id), set: [alliance_rank: "host"])
    Repo.update_all(from(p in Player, where: p.id == ^me.id), set: [alliance_rank: "vice"])
  end

  defp run(me, "setRank", %{"player" => name, "rank" => rank}) when is_binary(name) do
    allowed!(me, :set_rank)
    if rank not in Alliances.ranks(), do: Repo.rollback("bad_message")
    them = member!(me, name)

    if not (Alliances.above?(me.alliance_rank, them.alliance_rank) and
              Alliances.above?(me.alliance_rank, rank)),
       do: Repo.rollback("rank_too_low")

    Repo.update_all(from(p in Player, where: p.id == ^them.id), set: [alliance_rank: rank])
  end

  defp run(me, "diplomacy", %{"name" => name, "status" => status})
       when is_binary(name) and status in ["friendly", "neutral", "hostile"] do
    allowed!(me, :diplomacy)

    other =
      Repo.one(from a in Alliance, where: fragment("lower(?)", a.name) == ^String.downcase(String.trim(name))) ||
        Repo.rollback("no_alliance")

    if other.id == me.alliance_id, do: Repo.rollback("bad_message")
    mine = Repo.one!(from a in Alliance, where: a.id == ^me.alliance_id, lock: "FOR UPDATE")

    diplomacy =
      if status == "neutral",
        do: Map.delete(mine.diplomacy, other.id),
        else: Map.put(mine.diplomacy, other.id, status)

    mine |> Ecto.Changeset.change(diplomacy: diplomacy) |> Repo.update!()
  end

  defp run(me, "describe", %{"text" => text}) when is_binary(text) do
    allowed!(me, :describe)

    Repo.update_all(from(a in Alliance, where: a.id == ^me.alliance_id),
      set: [description: String.slice(String.trim(text), 0, 1000)]
    )
  end

  defp run(me, "disband", _args) do
    allowed!(me, :disband)
    disband(me.alliance_id)
  end

  defp run(_me, _action, _args), do: Repo.rollback("bad_message")

  # takes the player in if the alliance has room (its members locked first)
  defp admit(alliance_id, player_id) do
    alliance = Repo.one!(from a in Alliance, where: a.id == ^alliance_id, lock: "FOR UPDATE")
    if member_count(alliance.id) >= member_cap(alliance.id), do: Repo.rollback("alliance_full")
    enroll(player_id, alliance, "member")
  end

  defp disband(alliance_id) do
    Repo.update_all(from(p in Player, where: p.alliance_id == ^alliance_id),
      set: [alliance_id: nil, alliance: nil, alliance_rank: nil]
    )

    Repo.delete_all(from a in Alliance, where: a.id == ^alliance_id)
  end

  defp members(alliance_id), do: Repo.all(from p in Player, where: p.alliance_id == ^alliance_id)

  defp member!(me, name) do
    them =
      Repo.one(from p in Player, where: p.name == ^String.trim(name)) || Repo.rollback("player_not_found")

    if them.alliance_id != me.alliance_id, do: Repo.rollback("not_a_member")
    them
  end

  defp allowed!(me, action) do
    if me.alliance_id == nil, do: Repo.rollback("no_alliance")
    if not Alliances.can?(me.alliance_rank, action), do: Repo.rollback("rank_too_low")
    :ok
  end

  defp find_request(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.get(AllianceRequest, id)
      :error -> nil
    end
  end

  @doc "How player a's alliance sees player b's: \"alliance\", \"friendly\", \"hostile\" or nil."
  def relation(a, b) do
    case Repo.all(from p in Player, where: p.id in ^Enum.uniq([a, b]), select: {p.id, p.alliance_id})
         |> Map.new() do
      %{^a => mine, ^b => theirs} when mine != nil -> Alliances.relation(mine, theirs, diplomacy(mine))
      _ -> nil
    end
  end

  defp diplomacy(alliance_id),
    do: Repo.one(from a in Alliance, where: a.id == ^alliance_id, select: a.diplomacy) || %{}

  @doc "Every alliance id's diplomacy map for the given player's alliance (an empty map without one)."
  def my_diplomacy(player_id) do
    case Repo.one(from p in Player, where: p.id == ^player_id, select: p.alliance_id) do
      nil -> {nil, %{}}
      id -> {id, diplomacy(id)}
    end
  end
end
