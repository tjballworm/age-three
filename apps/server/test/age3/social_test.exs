defmodule Age3.SocialTest do
  # Chat and mail against Postgres. Run with: mix test --include db
  use ExUnit.Case, async: true

  @moduletag :db

  alias Age3.{Repo, Social, Store.Pg}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
  end

  defp player(name) do
    {:ok, id} = Pg.find_or_create_player(name)
    id
  end

  test "world and alliance chat, with a history and a speed limit" do
    a = player("Talker")
    b = player("Listener")
    now = System.system_time(:millisecond)

    assert {:ok, %{channel: "world", from: "Talker", text: "hello"}, :all} =
             Social.chat(a, "world", "  hello ", now)

    assert {:error, "too_fast"} = Social.chat(a, "world", "again", now + 500)
    assert {:error, "bad_message"} = Social.chat(b, "world", "   ", now)
    assert {:error, "no_alliance"} = Social.chat(b, "alliance", "psst", now)

    alliance = Repo.insert!(%Age3.Alliance{name: "Chatters"})
    Repo.update_all(Age3.Player, set: [alliance_id: alliance.id])
    assert {:ok, %{channel: "alliance"}, aid} = Social.chat(b, "alliance", "psst", now + 2000)
    assert aid == alliance.id
    assert Enum.sort(Social.alliance_members(aid)) == Enum.sort([a, b])
    assert [%{text: "hello"}, %{text: "psst"}] = Social.history(a)
  end

  test "mail: send, read, delete each side" do
    a = player("Writer")
    b = player("Reader")
    now = System.system_time(:millisecond)

    assert {:error, "player_not_found"} = Social.send_mail(a, "Nobody", "Hi", "There", now)
    assert {:error, "bad_message"} = Social.send_mail(a, "Writer", "Hi", "Me", now)
    assert {:error, "bad_message"} = Social.send_mail(a, "reader", " ", "There", now)
    assert {:ok, ^b} = Social.send_mail(a, "reader", "Hi", "There", now)
    assert Social.unread(b) == 1
    %{inbox: [mail], sent: []} = Social.mailbox(b)
    assert %{from: "Writer", subject: "Hi", read: false} = mail
    assert {:error, "bad_message"} = Social.read_mail(a, mail.id)
    assert :ok = Social.read_mail(b, mail.id)
    assert Social.unread(b) == 0
    assert :ok = Social.delete_mail(b, mail.id)
    assert %{inbox: []} = Social.mailbox(b)
    assert %{sent: [_]} = Social.mailbox(a)
    assert :ok = Social.delete_mail(a, mail.id)
    assert Repo.aggregate(Age3.Mail, :count) == 0
  end
end
