defmodule EhsEnforcement.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EhsEnforcementWeb.Telemetry,
      EhsEnforcement.Repo,
      {DNSCluster, query: Application.get_env(:ehs_enforcement, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EhsEnforcement.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: EhsEnforcement.Finch},
      # Start a worker by calling: EhsEnforcement.Worker.start_link(arg)
      # {EhsEnforcement.Worker, arg},
      # Start to serve requests, typically the last entry
      EhsEnforcementWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EhsEnforcement.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EhsEnforcementWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
