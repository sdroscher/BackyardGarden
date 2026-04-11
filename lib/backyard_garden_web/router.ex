defmodule BackyardGardenWeb.Router do
  use BackyardGardenWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BackyardGardenWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' ws: wss:"
    }
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Unauthenticated routes (OAuth flow)
  scope "/", BackyardGardenWeb do
    pipe_through :browser

    # Ueberauth handles the request phase (redirect to Auth0);
    # AuthController handles the callback and logout.
    get "/auth/auth0", AuthController, :request
    get "/auth/auth0/callback", AuthController, :callback
    get "/auth/logout", AuthController, :delete
  end

  pipeline :require_auth do
    plug BackyardGardenWeb.Plugs.RequireAuth
  end

  # Authenticated routes
  scope "/", BackyardGardenWeb do
    pipe_through [:browser, :require_auth]

    live "/", Dashboard.IndexLive, :index

    live "/seeds", Seeds.IndexLive, :index
    live "/seeds/new", Seeds.NewLive, :new
    live "/seeds/:id", Seeds.ShowLive, :show
    live "/seeds/:id/edit", Seeds.EditLive, :edit

    live "/garden", Garden.IndexLive, :index

    live "/calendar", Calendar.IndexLive, :index

    live "/settings", Settings.ProfileLive, :index
    live "/settings/zones", Settings.ZonesLive, :index
    live "/settings/notifications", Settings.NotificationsLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", BackyardGardenWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:backyard_garden, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BackyardGardenWeb.Telemetry
    end
  end
end
