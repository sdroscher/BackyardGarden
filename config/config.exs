# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :backyard_garden,
  ecto_repos: [BackyardGarden.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :backyard_garden, BackyardGarden.Repo,
  database: Path.expand("../priv/repo/backyard_garden.db", __DIR__),
  pool_size: 5

config :backyard_garden, Oban,
  repo: BackyardGarden.Repo,
  engine: Oban.Engines.Basic,
  peer: {Oban.Peers.Isolated, []},
  stage_interval: 1000,
  plugins: [
    {Oban.Plugins.Cron,
     crons: [
       hourly_check: [
         schedule: "0 * * * *",
         worker: "BackyardGarden.Workers.HourlyCheckWorker"
       ]
     ]}
  ]

# Configure the endpoint
config :backyard_garden, BackyardGardenWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BackyardGardenWeb.ErrorHTML, json: BackyardGardenWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BackyardGarden.PubSub,
  live_view: [signing_salt: "8+265krw"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  backyard_garden: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  backyard_garden: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :backyard_garden, :weather,
  base_url: "https://api.openweathermap.org",
  api_key: ""

config :backyard_garden, :default_location, "Victoria, BC"

config :backyard_garden, :timezone, "America/Vancouver"

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ueberauth, Ueberauth,
  providers: [
    auth0: {Ueberauth.Strategy.Auth0, []}
  ]

# Auth0 credentials are loaded from env in runtime.exs
config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: "placeholder.auth0.com",
  client_id: "placeholder",
  client_secret: "placeholder"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
