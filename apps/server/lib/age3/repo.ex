defmodule Age3.Repo do
  # The database connection pool (like internal/db). Queries go through it: Repo.get, Repo.insert, ...
  use Ecto.Repo, otp_app: :age3, adapter: Ecto.Adapters.Postgres

  require Logger

  # Runs when the pool starts. Turns DATABASE_URL into connection settings.
  @impl true
  def init(_type, config) do
    case System.get_env("DATABASE_URL") do
      url when url in [nil, ""] ->
        if config[:hostname] || config[:url],
          do: {:ok, config},
          else: raise("DATABASE_URL is not set (see apps/server/.env.example)")

      url ->
        {:ok, Keyword.merge(config, connection_opts(url))}
    end
  end

  @doc """
  Connection settings for a postgres:// URL. Hosted databases (Neon) get TLS with the server's certificate
  checked; localhost does not, unless the URL asks for it with sslmode. Errors never include the password.
  """
  def connection_opts(url) do
    uri = URI.parse(url)

    unless uri.scheme in ["postgres", "postgresql"] and is_binary(uri.host) and uri.host != "" and
             is_binary(uri.path) and uri.path != "/" do
      raise ArgumentError,
            "DATABASE_URL is not a valid postgres:// URL (expected postgres://user:password@host/database)"
    end

    {username, password} =
      case String.split(uri.userinfo || "", ":", parts: 2) do
        [user, pass] -> {URI.decode(user), URI.decode(pass)}
        [user] -> {URI.decode(user), nil}
      end

    params = URI.decode_query(uri.query || "")
    local? = uri.host in ["localhost", "127.0.0.1", "::1"]
    ssl? = Map.get(params, "sslmode", if(local?, do: "disable", else: "require")) != "disable"

    [
      hostname: uri.host,
      port: uri.port || 5432,
      database: String.trim_leading(uri.path, "/"),
      username: username,
      password: password,
      ssl: if(ssl?, do: ssl_opts(uri.host), else: false)
    ]
  end

  defp ssl_opts(host) do
    host = String.to_charlist(host)

    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      # Neon finds the right database from the host name sent here
      server_name_indication: host,
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
  end
end
