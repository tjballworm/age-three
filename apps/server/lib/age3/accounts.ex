defmodule Age3.Accounts do
  # Logins: checking a username and password, and the tokens that keep a browser logged in.
  #
  # There's no sign-up yet; TJ creates accounts by hand with set_password/2:
  #   locally:  iex -S mix   then   Age3.Accounts.set_password("Lord TJ")
  #   on Fly:   fly ssh console -a age-three-server
  #             then   /app/bin/age3 rpc 'Age3.Accounts.set_password("Lord TJ")'
  # It creates the player (with a starter city) if the name is new, sets a random password, and prints it.
  @moduledoc false

  import Ecto.Query
  alias Age3.{AuthToken, Password, Player, Repo, Store}

  # how long a login lasts before the player has to type the password again
  @token_days 30
  @valid_name ~r/^[A-Za-z0-9 _'-]{3,24}$/

  @doc """
  Sets a player's password, creating the player if the name is new, and logs them out everywhere.
  Leave out the password to get a random one. Prints the username and password to hand to the player.
  """
  def set_password(name, password \\ Password.generate()) when is_binary(name) and is_binary(password) do
    name = String.trim(name)

    cond do
      not Regex.match?(@valid_name, name) -> {:error, "name must be 3-24 letters, numbers or spaces"}
      String.length(password) < 8 -> {:error, "password must be at least 8 characters"}
      true -> do_set_password(name, password)
    end
  end

  defp do_set_password(name, password) do
    with {:ok, player_id} <- Store.Pg.find_or_create_player(name) do
      Repo.transaction(fn ->
        hash = Password.hash(password)
        Repo.update_all(from(p in Player, where: p.id == ^player_id), set: [password_hash: hash])
        # a new password signs out every browser that was logged in with the old one
        Repo.delete_all(from(t in AuthToken, where: t.player_id == ^player_id))
      end)

      IO.puts("username: #{name}\npassword: #{password}")
      :ok
    end
  end

  @doc "The player's id if the username and password match."
  def authenticate(name, password) when is_binary(name) and is_binary(password) do
    case Repo.one(from p in Player, where: p.name == ^name, select: {p.id, p.password_hash}) do
      {id, hash} when is_binary(hash) ->
        if Password.verify(password, hash), do: {:ok, id}, else: :error

      # unknown name, or no password set: take as long as a real check, so the reply time doesn't say which
      _ ->
        Password.no_user_verify()
        :error
    end
  end

  @doc "Makes a new login token for the player. The browser keeps it and sends it back on its next visit."
  def new_token(player_id) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    Repo.insert!(%AuthToken{token_hash: digest(token), player_id: player_id})
    token
  end

  @doc "The player a token belongs to, if it exists and hasn't expired."
  def player_for_token(token) when is_binary(token) do
    cutoff = DateTime.add(DateTime.utc_now(), -@token_days, :day)

    query =
      from t in AuthToken,
        where: t.token_hash == ^digest(token) and t.inserted_at > ^cutoff,
        select: t.player_id

    case Repo.one(query) do
      nil -> :error
      player_id -> {:ok, player_id}
    end
  end

  defp digest(token), do: :crypto.hash(:sha256, token)
end
