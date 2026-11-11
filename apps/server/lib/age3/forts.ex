defmodule Age3.Forts do
  # Wall fortifications players build, as pure functions (no database): traps, abatis, archer towers, rolling
  # logs and defensive trebuchets (priv/data/fortifications.json, the wiki's Walls page). Each takes space on the
  # walls (1 to 5), and the walls give 1,000 spaces at Lv1 up to 55,000 at Lv10; batches being built count as if
  # they were done. Each type needs a walls level and some research (Archer's Tower: Walls 3 and Archery 3).
  # They are built at the walls in batches, one after another: as many batches as the walls level can wait in
  # line, like a Barracks. Construction research makes them faster (x0.9 per level), as does the mayor's
  # Politics (x0.995 per point, wiki: Stats). A cancelled batch gives its whole cost back.
  #
  # In battle they defend the city whether its gate is open or not. Those used up are gone, but Machinery repairs
  # 3% of the losses per level afterwards, at most 30% (the battle calc guide's estimate).
  @moduledoc false

  alias Age3.{Build, Data, Research}

  # sanity limit for one batch; space and resources limit it long before this
  @max_batch 1_000_000

  @doc "Space these fortifications (%{\"trap\" => 10, ...}) take on the walls."
  def used(forts), do: Enum.sum(for {f, n} <- forts || %{}, spec = Data.fort(f), do: n * spec["space"])

  @doc """
  Can the city build count of fort? buildings is the city's, research the player's (capped in the city here),
  resources the settled resources, forts those built, queued the batches being built (a list of {fort, count}),
  politics the mayor's (or 0). Returns {:ok, %{cost, seconds}} or {:error, code}.
  """
  def check(buildings, research, resources, forts, queued, fort, count, politics \\ 0) do
    research = Research.in_city(research, buildings)
    walls = Build.level_of(buildings, "walls")
    spec = Data.fort(fort)

    with %{} <- spec || {:error, "bad_message"},
         true <- (is_integer(count) and count >= 1 and count <= @max_batch) || {:error, "bad_message"},
         :ok <- if(walls >= spec["walls"], do: :ok, else: {:error, "requirement_not_met"}),
         :ok <-
           if(Research.met?(buildings, research, %{"research" => spec["research"]}),
             do: :ok,
             else: {:error, "requirement_not_met"}
           ),
         :ok <- if(length(queued) < max(1, walls), do: :ok, else: {:error, "fort_queue_full"}),
         :ok <- room(walls, forts, queued, spec["space"] * count),
         cost = Map.new(spec["cost"], fn {k, v} -> {k, v * count} end),
         :ok <- Build.affordable(resources, cost) do
      {:ok, %{cost: cost, seconds: seconds(fort, count, research, politics)}}
    end
  end

  defp room(walls, forts, queued, more) do
    taken =
      used(forts) + used(Enum.reduce(queued, %{}, fn {f, n}, acc -> Map.update(acc, f, n, &(&1 + n)) end))

    if taken + more <= Data.fort_spaces(walls), do: :ok, else: {:error, "no_wall_space"}
  end

  @doc "Seconds to build count of fort: per unit x count, x0.9 per Construction level, x0.995 per Politics point."
  def seconds(fort, count, research, politics \\ 0) do
    base = Data.fort(fort)["seconds"] * count

    max(
      1,
      round(
        base * :math.pow(0.9, Research.level_of(research, "construction")) *
          :math.pow(0.995, max(0, politics))
      )
    )
  end

  @doc """
  The fortifications left after a battle: what it didn't use plus what the defender's Machinery repaired (the
  battle engine works that out: 3% of the used ones per level, at most 30%). before is what the city had.
  """
  def after_battle(before, result) do
    back = Map.new(result.fortifications, &{&1.type, &1.remaining + &1.repaired})
    for {f, n} <- before || %{}, n > 0, into: %{}, do: {f, min(n, Map.get(back, f, n))}
  end
end
