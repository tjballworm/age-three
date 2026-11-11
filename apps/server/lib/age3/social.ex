defmodule Age3.Social do
  # Server chat and mail against Postgres. Chat has two channels: world (everyone) and alliance (the sender's
  # alliance). Lines are kept and the latest 50 per channel are sent on login; new ones are pushed to the open
  # games they reach (Age3.Session does the pushing). Mail is player to player: a subject, a body, read or not,
  # and each side may delete its copy.
  @moduledoc false

  import Ecto.Query

  alias Age3.{ChatMessage, Mail, Player, Repo}

  @history 50
  @text_length 200
  @subject_length 100
  @body_length 5_000
  @mail_list 100
  # one line per second, so a held Enter can't flood the world channel
  @chat_gap_ms 1_000

  @doc """
  Posts a chat line: channel "world" or "alliance", text trimmed to 200 characters. Returns {:ok, line, to} where
  to is :all (world) or the alliance id, or {:error, code} ("no_alliance", "bad_message", "too_fast").
  """
  def chat(player_id, channel, text, now_ms) when channel in ["world", "alliance"] and is_binary(text) do
    text = text |> String.trim() |> String.slice(0, @text_length)
    player = Repo.get!(Player, player_id)

    last =
      Repo.one(from m in ChatMessage, where: m.player_id == ^player_id, select: max(m.inserted_at))

    cond do
      text == "" ->
        {:error, "bad_message"}

      channel == "alliance" and player.alliance_id == nil ->
        {:error, "no_alliance"}

      last &&
          DateTime.diff(DateTime.from_unix!(now_ms * 1000, :microsecond), last, :millisecond) < @chat_gap_ms ->
        {:error, "too_fast"}

      true ->
        alliance_id = if channel == "alliance", do: player.alliance_id

        line =
          Repo.insert!(%ChatMessage{
            alliance_id: alliance_id,
            player_id: player.id,
            name: player.name,
            text: text,
            inserted_at: DateTime.from_unix!(now_ms * 1000, :microsecond)
          })

        {:ok, chat_json(line), alliance_id || :all}
    end
  end

  def chat(_player_id, _channel, _text, _now_ms), do: {:error, "bad_message"}

  @doc "The latest world lines and the player's alliance's, oldest first."
  def history(player_id) do
    alliance_id = Repo.one(from p in Player, where: p.id == ^player_id, select: p.alliance_id)

    world = latest(from m in ChatMessage, where: is_nil(m.alliance_id))

    alliance =
      if alliance_id, do: latest(from m in ChatMessage, where: m.alliance_id == ^alliance_id), else: []

    Enum.sort_by(world ++ alliance, & &1.at)
  end

  defp latest(query),
    do:
      Repo.all(from m in query, order_by: [desc: m.inserted_at], limit: @history)
      |> Enum.map(&chat_json/1)

  defp chat_json(m),
    do: %{
      id: m.id,
      channel: if(m.alliance_id, do: "alliance", else: "world"),
      from: m.name,
      text: m.text,
      at: DateTime.to_unix(m.inserted_at, :millisecond)
    }

  @doc "The players of an alliance (whose open games get its chat lines)."
  def alliance_members(alliance_id),
    do: Repo.all(from p in Player, where: p.alliance_id == ^alliance_id, select: p.id)

  @doc """
  Sends a mail to the player named to. Returns {:ok, receiver_id} or {:error, code} ("player_not_found",
  "bad_message" for an empty subject or body, or one to yourself).
  """
  def send_mail(player_id, to, subject, body, now_ms)
      when is_binary(to) and is_binary(subject) and is_binary(body) do
    subject = subject |> String.trim() |> String.slice(0, @subject_length)
    body = body |> String.trim() |> String.slice(0, @body_length)
    from = Repo.get!(Player, player_id)

    receiver =
      Repo.one(from p in Player, where: fragment("lower(?)", p.name) == ^String.downcase(String.trim(to)))

    cond do
      receiver == nil ->
        {:error, "player_not_found"}

      receiver.id == from.id or subject == "" or body == "" ->
        {:error, "bad_message"}

      true ->
        Repo.insert!(%Mail{
          from_id: from.id,
          to_id: receiver.id,
          from_name: from.name,
          to_name: receiver.name,
          subject: subject,
          body: body,
          inserted_at: DateTime.from_unix!(now_ms * 1000, :microsecond)
        })

        {:ok, receiver.id}
    end
  end

  def send_mail(_player_id, _to, _subject, _body, _now_ms), do: {:error, "bad_message"}

  @doc "The player's inbox and sent mail, newest first (100 of each)."
  def mailbox(player_id) do
    inbox =
      Repo.all(
        from m in Mail,
          where: m.to_id == ^player_id and not m.receiver_deleted,
          order_by: [desc: m.inserted_at],
          limit: @mail_list
      )

    sent =
      Repo.all(
        from m in Mail,
          where: m.from_id == ^player_id and not m.sender_deleted,
          order_by: [desc: m.inserted_at],
          limit: @mail_list
      )

    %{inbox: Enum.map(inbox, &mail_json/1), sent: Enum.map(sent, &mail_json/1)}
  end

  defp mail_json(m),
    do: %{
      id: m.id,
      from: m.from_name,
      to: m.to_name,
      subject: m.subject,
      body: m.body,
      read: m.read,
      at: DateTime.to_unix(m.inserted_at, :millisecond)
    }

  @doc "How many unread mails the player has."
  def unread(player_id),
    do:
      Repo.aggregate(
        from(m in Mail, where: m.to_id == ^player_id and not m.read and not m.receiver_deleted),
        :count
      )

  @doc "Marks a received mail read. :ok or {:error, \"bad_message\"}."
  def read_mail(player_id, mail_id) do
    with {:ok, id} <- Ecto.UUID.cast(mail_id),
         {1, _} <-
           Repo.update_all(from(m in Mail, where: m.id == ^id and m.to_id == ^player_id), set: [read: true]) do
      :ok
    else
      _ -> {:error, "bad_message"}
    end
  end

  @doc "Deletes the player's copy of a mail (received or sent); the row goes when both sides have."
  def delete_mail(player_id, mail_id) do
    with {:ok, id} <- Ecto.UUID.cast(mail_id),
         %Mail{} = m <- Repo.get(Mail, id),
         true <- m.to_id == player_id or m.from_id == player_id do
      m =
        m
        |> Ecto.Changeset.change(
          receiver_deleted: m.receiver_deleted or m.to_id == player_id,
          sender_deleted: m.sender_deleted or m.from_id == player_id
        )
        |> Repo.update!()

      if m.receiver_deleted and (m.sender_deleted or m.from_id == nil), do: Repo.delete!(m)
      :ok
    else
      _ -> {:error, "bad_message"}
    end
  end
end
