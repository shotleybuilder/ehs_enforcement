defmodule EhsEnforcement.Repo do
  use Ecto.Repo,
    otp_app: :ehs_enforcement,
    adapter: Ecto.Adapters.Postgres
end
