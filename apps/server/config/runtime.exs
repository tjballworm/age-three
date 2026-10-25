# Read when the server starts (also in the release on Fly), so it can use environment variables.
# In dev and test it first loads apps/server/.env, without overriding variables that are already set.
import Config

if config_env() != :prod and File.exists?(".env") do
  for line <- File.stream!(".env"),
      line = String.trim(line),
      line != "" and not String.starts_with?(line, "#"),
      [key, value] <- [String.split(line, "=", parts: 2)],
      System.get_env(String.trim(key)) == nil do
    System.put_env(String.trim(key), String.trim(value))
  end
end

config :age3, Age3Web.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "8080"))],
  server: Application.get_env(:age3, :start_server, true)

# DATABASE_URL itself is read in Age3.Repo.init/2, which turns it into connection settings.
