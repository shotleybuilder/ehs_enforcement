defmodule EhsEnforcementWeb.Router do
  use EhsEnforcementWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EhsEnforcementWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EhsEnforcementWeb do
    pipe_through :browser

    get "/home", PageController, :home
    live "/", DashboardLive, :index
    live "/dashboard", DashboardLive, :index
    
    # Case Management Routes
    live "/cases", CaseLive.Index, :index
    get "/cases/export.csv", CaseController, :export_csv
    get "/cases/export.xlsx", CaseController, :export_excel
    get "/cases/export_detailed.csv", CaseController, :export_detailed_csv
    live "/cases/new", CaseLive.Form, :new
    live "/cases/:id", CaseLive.Show, :show
    live "/cases/:id/edit", CaseLive.Form, :edit
    
    # Notice Management Routes
    live "/notices", NoticeLive.Index, :index
    live "/notices/:id", NoticeLive.Show, :show
    
    # Offender Management Routes
    live "/offenders", OffenderLive.Index, :index
    live "/offenders/:id", OffenderLive.Show, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", EhsEnforcementWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ehs_enforcement, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EhsEnforcementWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
