# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ehs_enforcement,
  ecto_repos: [EhsEnforcement.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :ehs_enforcement, EhsEnforcementWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: EhsEnforcementWeb.ErrorHTML, json: EhsEnforcementWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EhsEnforcement.PubSub,
  live_view: [signing_salt: "TcQJOqoT"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :ehs_enforcement, EhsEnforcement.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  ehs_enforcement: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  ehs_enforcement: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Ash configuration
config :ash, :utc_datetime_type, :datetime
config :ash, :disable_async?, true

# Configure AshPostgres
config :ehs_enforcement, EhsEnforcement.Repo,
  extensions: [AshPostgres.Repo]

# Ash domain configuration
config :ehs_enforcement, ash_domains: [
  EhsEnforcement.Enforcement,
  EhsEnforcement.Sync
]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
