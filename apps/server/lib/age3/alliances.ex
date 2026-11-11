defmodule Age3.Alliances do
  # Alliance rules as pure functions (the wiki's Alliance and Embassy pages). Joining (applying, or accepting an
  # invitation) needs an Embassy; founding one needs Embassy Lv2 and 10,000 gold. The member limit is 10 per level
  # of the host's best Embassy (100 at Lv10). Ranks, lowest first: Member, Officer, Presbyter, Vice Host, Host.
  #
  # Who may do what (the wiki only says each rank above Member has its own powers; this split is ours, tunable):
  #   * Officer and up: invite players, accept or reject applications.
  #   * Presbyter and up: remove members ranked below them.
  #   * Vice Host and up: set ranks below their own, diplomacy (friendly / neutral / hostile), the description.
  #   * Host: everything, hand the alliance to another member, disband it. A host who leaves hands it to the
  #     highest-ranked member first (or disbands it when alone).
  #
  # Members of one alliance can't attack or scout each other, and neither can an alliance its "friendly" ones
  # (the wiki: friendly alliances can't be attacked; it is one-sided, so both hosts should set it).
  @moduledoc false

  @ranks ~w(member officer presbyter vice host)
  @create_gold 10_000
  @name_length 3..20

  def ranks, do: @ranks
  def create_gold, do: @create_gold

  @doc "A rank's place, Member 1 to Host 5 (0 for none)."
  def rank_value(rank), do: Enum.find_index(@ranks, &(&1 == rank)) |> then(&if(&1, do: &1 + 1, else: 0))

  @doc "How many members an alliance may have with the host's best Embassy at this level: 10 per level."
  def member_cap(embassy), do: 10 * min(max(embassy, 1), 10)

  @doc "May a player of rank do this? action is :invite, :accept, :kick, :set_rank, :diplomacy, :describe, :host or :disband."
  def can?(rank, action) do
    need =
      case action do
        a when a in [:invite, :accept] -> "officer"
        :kick -> "presbyter"
        a when a in [:set_rank, :diplomacy, :describe] -> "vice"
        a when a in [:host, :disband] -> "host"
      end

    rank_value(rank) >= rank_value(need)
  end

  @doc "Can someone of rank `mine` remove, or change the rank of, someone of rank `theirs`? Only those below."
  def above?(mine, theirs), do: rank_value(mine) > rank_value(theirs)

  @doc "A name is 3 to 20 letters, digits, spaces, - or _, after trimming. Returns {:ok, name} or {:error, \"bad_name\"}."
  def name(name) when is_binary(name) do
    name = String.trim(name)

    if String.length(name) in @name_length and Regex.match?(~r/^[\p{L}\p{N} _-]+$/u, name),
      do: {:ok, name},
      else: {:error, "bad_name"}
  end

  def name(_), do: {:error, "bad_name"}

  @doc "The member who takes over from a leaving host: the highest rank, then the longest in the alliance."
  def successor(members), do: Enum.max_by(members, &rank_value(&1.alliance_rank), fn -> nil end)

  @doc """
  How one player's alliance sees another's: "alliance" (the same), "friendly" or "hostile" (by the first one's
  diplomacy), else nil. mine and theirs are alliance ids (nil without one).
  """
  def relation(nil, _theirs, _diplomacy), do: nil
  def relation(_mine, nil, _diplomacy), do: nil
  def relation(same, same, _diplomacy), do: "alliance"
  def relation(_mine, theirs, diplomacy), do: Map.get(diplomacy || %{}, theirs)

  @doc "May an attack or scout go from a player of alliance mine (with its diplomacy) to one of theirs?"
  def may_attack?(mine, theirs, diplomacy),
    do: relation(mine, theirs, diplomacy) not in ["alliance", "friendly"]
end
