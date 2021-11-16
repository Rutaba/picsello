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

  scope "/stripe" do
    pipeline :webhooks do
      plug PicselloWeb.Plugs.StripeWebhooks
    end

    pipe_through :webhooks
    post "/connect-webhooks", PicselloWeb.StripeConnectWebhooksController, :webhooks
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

  scope "/", PicselloWeb do
    pipe_through :browser

    unless Mix.env() in [:dev, :test], do: pipe_through(:admins_only)
    live_dashboard "/dashboard", metrics: Telemetry, ecto_repos: [Repo]
    live "/admin/categories", Live.Admin.Categories, :index
  end

  ## Authentication routes

  scope "/", PicselloWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live "/", PageLive, :index
    live "/users/register", UserRegisterLive, :new, as: :user_registration
    post "/users/register", UserRegistrationController, :create
    live "/users/log_in", UserSessionNewLive, :new, as: :user_session
    post "/users/log_in", UserSessionController, :create
    live "/users/reset_password", UserResetPasswordNewLive, :new, as: :user_reset_password

    live "/users/reset_password/:token", UserResetPasswordEditLive, :edit,
      as: :user_reset_password
  end

  scope "/auth", PicselloWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/", PicselloWeb do
    live_session :default, on_mount: PicselloWeb.LiveAuth do
      pipe_through [:browser, :require_authenticated_user]

      put "/users/settings", UserSettingsController, :update
      get "/users/settings/stripe-refresh", UserSettingsController, :stripe_refresh
      get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
      live "/users/settings", Live.User.Settings, :edit
      live "/package_templates", Live.PackageTemplates, :index
      live "/pricing", Live.Pricing, :index

      live "/home", HomeLive.Index, :index, as: :home
      live "/leads/:id", LeadLive.Show, :leads, as: :job
      live "/leads", JobLive.Index, :leads, as: :job
      live "/jobs/:id", JobLive.Show, :jobs, as: :job
      live "/jobs", JobLive.Index, :jobs, as: :job
      live "/jobs/:id/shoot/:shoot_number", JobLive.Shoot, :jobs, as: :shoot
      live "/leads/:id/shoot/:shoot_number", JobLive.Shoot, :leads, as: :shoot

      live "/onboarding", OnboardingLive.Index, :index, as: :onboarding
    end
  end

  scope "/", PicselloWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm

    live "/proposals/:token", BookingProposalLive.Show, :show, as: :booking_proposal

    # Photographers CRUD for gallery
    live "/galleries", GalleryLive.Index, :index
    live "/galleries/new", GalleryLive.Index, :new
    live "/galleries/:id/edit", GalleryLive.Index, :edit

    live "/galleries/:id", GalleryLive.Show, :show
    live "/galleries/:id/upload", GalleryLive.Show, :upload
    live "/galleries/:id/settings", GalleryLive.Settings, :settings
  end

  scope "/gallery", PicselloWeb do
    pipe_through [:browser]

    live "/:hash", GalleryLive.ClientShow, :show
    post "/:hash/downloads", GalleryDownloadsController, :download
  end
end
