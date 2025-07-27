import Config

# Set the environment
config :ehs_enforcement, :environment, :test

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ehs_enforcement, EhsEnforcement.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ehs_enforcement_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ehs_enforcement, EhsEnforcementWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "qQwK7Em234fldhImb233J+SsBWx/chBaje2paAYNK5G9RkV111KRX0EBS/b1QUwf",
  server: false

# In test we don't send emails
config :ehs_enforcement, EhsEnforcement.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure mock Airtable client for testing
config :ehs_enforcement, :airtable_client, EhsEnforcement.Test.MockAirtableClient

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ehs_enforcement, EhsEnforcement.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ehs_enforcement_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ehs_enforcement, EhsEnforcementWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "hGe1tmcVlrGzm+kUIe+WDdvfqAipCfeCyhdS7Tglz9mhOoA7N74PCaHIANh5hZHq",
  server: false

# In test we don't send emails
config :ehs_enforcement, EhsEnforcement.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
