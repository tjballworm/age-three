defmodule Age3.Password do
  # Password hashing with PBKDF2-SHA256 from Erlang's built-in :crypto, so no extra dependency is needed.
  # A stored hash looks like "pbkdf2-sha256$600000$<salt>$<key>": the method, how many rounds, a random salt,
  # and the derived key. Keeping the rounds in the string means old hashes still verify if the count changes.
  @moduledoc false

  @salt_bytes 16
  @key_bytes 32
  # the same salt every time is fine here: it's only used to spend the same time when a username doesn't exist
  @dummy_salt <<0::128>>

  # Slow on purpose (about a tenth of a second), so guessing passwords is slow too. Tests turn it down.
  defp rounds, do: Application.get_env(:age3, :pbkdf2_rounds, 600_000)

  @doc "Hashes a password with a fresh random salt."
  def hash(password) when is_binary(password) do
    salt = :crypto.strong_rand_bytes(@salt_bytes)
    rounds = rounds()
    key = derive(password, salt, rounds, @key_bytes)
    Enum.join(["pbkdf2-sha256", rounds, b64(salt), b64(key)], "$")
  end

  @doc "True if the password matches the stored hash."
  def verify(password, stored) when is_binary(password) and is_binary(stored) do
    with ["pbkdf2-sha256", rounds, salt, key] <- String.split(stored, "$"),
         {rounds, ""} when rounds > 0 <- Integer.parse(rounds),
         {:ok, salt} <- Base.url_decode64(salt, padding: false),
         {:ok, key} when key != "" <- Base.url_decode64(key, padding: false) do
      # hash_equals takes the same time however many bytes match, so timing doesn't leak the key
      :crypto.hash_equals(key, derive(password, salt, rounds, byte_size(key)))
    else
      _ -> false
    end
  end

  @doc "Does the same work as verify/2, then returns false. For unknown users, so that answer isn't faster."
  def no_user_verify do
    derive("", @dummy_salt, rounds(), @key_bytes)
    false
  end

  @doc "A random password that's easy to read out: 12 letters and digits, no look-alikes like O/0 or l/1."
  def generate do
    alphabet = ~c"abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    for _ <- 1..12, into: "", do: <<Enum.random(alphabet)>>
  end

  defp derive(password, salt, rounds, length),
    do: :crypto.pbkdf2_hmac(:sha256, password, salt, rounds, length)

  defp b64(bytes), do: Base.url_encode64(bytes, padding: false)
end
