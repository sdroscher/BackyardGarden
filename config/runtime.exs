import Config

if config_env() == :dev do
  {:ok, env} = Dotenvy.source([".env", System.get_env()])
  System.put_env(env)

  config :backyard_garden, BackyardGarden.Repo, url: System.get_env("DATABASE_URL")
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/backyard_garden start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :backyard_garden, BackyardGardenWeb.Endpoint, server: true
end

config :backyard_garden, BackyardGardenWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

cloak_key =
  System.get_env("CLOAK_KEY") ||
    if config_env() == :prod do
      raise "environment variable CLOAK_KEY is missing. Generate with: mix run -e 'IO.puts Base.encode64(:crypto.strong_rand_bytes(32))'"
    else
      # Dev/test stable fallback — paste a real key from the command above into .env as CLOAK_KEY=<value>
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    end

config :backyard_garden, BackyardGarden.Vault,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!(cloak_key)}
  ]

config :backyard_garden, :weather,
  base_url: "https://api.openweathermap.org",
  api_key: System.get_env("OPENWEATHERMAP_API_KEY", "")

config :backyard_garden, :default_location, System.get_env("DEFAULT_LOCATION", "Victoria, BC")

config :backyard_garden, :timezone, System.get_env("TIMEZONE", "America/Vancouver")

config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: System.get_env("AUTH0_DOMAIN", "placeholder.auth0.com"),
  client_id: System.get_env("AUTH0_CLIENT_ID", "placeholder"),
  client_secret: System.get_env("AUTH0_CLIENT_SECRET", "placeholder")

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing."

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :backyard_garden, BackyardGarden.Repo,
    url: database_url,
    socket_options: maybe_ipv6,
    idle_interval: 30_000

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :backyard_garden, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :backyard_garden, BackyardGardenWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :backyard_garden, BackyardGardenWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :backyard_garden, BackyardGardenWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
