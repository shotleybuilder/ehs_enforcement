defmodule EhsEnforcementWeb.Router do
  use EhsEnforcementWeb, :router
  use AshAuthentication.Phoenix.Router
  
  import EhsEnforcementWeb.Plugs.AuthHelpers, only: [load_current_user: 2]
  
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EhsEnforcementWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_current_user
  end
  
  pipeline :auth_required do
    plug EhsEnforcementWeb.Plugs.AuthHelpers, :require_authenticated_user
  end
  
  pipeline :admin_required do
    plug EhsEnforcementWeb.Plugs.AuthHelpers, :require_authenticated_user
    plug EhsEnforcementWeb.Plugs.AuthHelpers, :require_admin_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end
  
  # Authentication routes
  scope "/", EhsEnforcementWeb do
    pipe_through :browser
    
    sign_in_route()
    sign_out_route AuthController
    auth_routes_for EhsEnforcement.Accounts.User, to: AuthController
    reset_route []
  end
  
  # Public routes - no authentication required  
  scope "/", EhsEnforcementWeb do
    pipe_through :browser

    get "/home", PageController, :home
    
    live_session :public,
      on_mount: AshAuthentication.Phoenix.LiveSession,
      session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []} do
      
      live "/", DashboardLive, :index
      live "/dashboard", DashboardLive, :index
      
      # Read-only Case Management Routes
      live "/cases", CaseLive.Index, :index
      live "/cases/:id", CaseLive.Show, :show
      
      # Read-only Notice Management Routes
      live "/notices", NoticeLive.Index, :index
      live "/notices/:id", NoticeLive.Show, :show
      
      # Read-only Offender Management Routes
      live "/offenders", OffenderLive.Index, :index
      live "/offenders/:id", OffenderLive.Show, :show
      
      # Reports & Analytics Routes (Open Access)
      live "/reports", ReportsLive.Index, :index
    end
    
    # Non-LiveView routes
    get "/cases/export.csv", CaseController, :export_csv
    get "/cases/export.xlsx", CaseController, :export_excel
    get "/cases/export_detailed.csv", CaseController, :export_detailed_csv
  end
  
  # Admin-only routes - require authentication and admin privileges
  scope "/", EhsEnforcementWeb do
    pipe_through [:browser, :admin_required]
    
    live_session :admin,
      on_mount: AshAuthentication.Phoenix.LiveSession,
      session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []} do
      
      # Admin Case Management Routes  
      live "/cases/new", CaseLive.Form, :new
      live "/cases/:id/edit", CaseLive.Form, :edit
      
      # Admin Notice Management Routes
      live "/notices/new", NoticeLive.Form, :new
      live "/notices/:id/edit", NoticeLive.Form, :edit
    end
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
