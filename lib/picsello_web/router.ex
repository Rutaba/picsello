defmodule PicselloWeb.Router do
  use PicselloWeb, :router

  import PicselloWeb.UserAuth

  if Mix.env() == :dev do
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PicselloWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admins_only do
    plug :admin_basic_auth
  end

  defp admin_basic_auth(conn, _opts),
    do:
      Plug.BasicAuth.basic_auth(conn,
        username: System.fetch_env!("ADMIN_USERNAME"),
        password: System.fetch_env!("ADMIN_PASSWORD")
      )

  scope "/health_check" do
    forward "/", PicselloWeb.Plugs.HealthCheck
  end

  # Other scopes may use custom stacks.
  # scope "/api", PicselloWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  import Phoenix.LiveDashboard.Router

  scope "/" do
    pipe_through :browser

    unless Mix.env() in [:dev, :test], do: pipe_through(:admins_only)
    live_dashboard "/dashboard", metrics: PicselloWeb.Telemetry, ecto_repos: [Picsello.Repo]
  end

  ## Authentication routes

  scope "/", PicselloWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live "/", PageLive, :index
    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    live "/users/log_in", UserSessionNewLive, :new, as: :user_session
    post "/users/log_in", UserSessionController, :create
    live "/users/reset_password", UserResetPasswordNewLive, :new, as: :user_reset_password

    live "/users/reset_password/:token", UserResetPasswordEditLive, :edit,
      as: :user_reset_password
  end

  scope "/", PicselloWeb do
    pipe_through [:browser, :require_authenticated_user]

    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
    live "/users/settings", Live.User.Settings, :edit

    live "/home", HomeLive.Index, :index, as: :home
    live "/jobs/:job_id/packages/new", PackageLive.New, :new, as: :job_package
    live "/jobs/new", JobLive.New, :new, as: :job
    live "/jobs/:id", JobLive.Show, :show, as: :job
    live "/jobs", JobLive.Index, :index, as: :job
  end

  scope "/", PicselloWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm
  end
end
