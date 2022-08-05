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

  pipeline :browser_iframe do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PicselloWeb.LayoutView, :root}
    plug :put_secure_browser_headers
    plug PicselloWeb.Plugs.AllowIframe
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admins_only do
    plug :admin_basic_auth
  end

  pipeline :param_auth do
    plug PicselloWeb.Plugs.GalleryParamAuth
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

  scope "/sendgrid" do
    post "/inbound-parse", PicselloWeb.SendgridInboundParseController, :parse
  end

  scope "/stripe" do
    post "/connect-webhooks", PicselloWeb.StripeWebhooksController, :connect_webhooks
    post "/app-webhooks", PicselloWeb.StripeWebhooksController, :app_webhooks
  end

  scope "/whcc" do
    post "/webhook", PicselloWeb.WhccWebhookController, :webhook
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

  scope "/admin", PicselloWeb do
    pipe_through :browser

    unless Mix.env() in [:dev, :test], do: pipe_through(:admins_only)
    live_dashboard "/dashboard", metrics: Telemetry, ecto_repos: [Repo]
    live "/categories", Live.Admin.Categories, :index
    live "/pricing_calculator", Live.Admin.PricingCalculator, :index
    live "/subscription_pricing", Live.Admin.SubscriptionPricing, :index
    live "/product_pricing", Live.Admin.ProductPricing, :index
    live "/product_pricing/:id", Live.Admin.ProductPricing, :show
    live "/workers", Live.Admin.Workers, :index
    live "/", Live.Admin.Index, :index
  end

  ## Authentication routes

  scope "/", PicselloWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live "/", PageLive, :index
    live "/users/register", UserRegisterLive, :new, as: :user_registration
    post "/users/register", UserRegistrationController, :create
    live "/users/log_in", Live.Session.New, :new, as: :user_session
    post "/users/log_in", UserSessionController, :create
    live "/users/reset_password", Live.PasswordReset.New, :new, as: :user_reset_password

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
      live "/contacts", Live.Contacts, :index, as: :contacts
      live "/brand", Live.BrandSettings, :index, as: :brand_settings
      live "/finance", Live.FinanceSettings, :index, as: :finance_settings
      live "/marketing", Live.Marketing, :index, as: :marketing
      live "/users/settings", Live.User.Settings, :edit
      live "/package_templates/:id/edit", Live.PackageTemplates, :edit
      live "/package_templates/new", Live.PackageTemplates, :new
      live "/package_templates", Live.PackageTemplates, :index
      live "/pricing/categories/:category_id", Live.Pricing.Category, :show
      live "/pricing", Live.Pricing, :index
      live "/pricing/calculator", Live.Pricing.Calculator.Index, :index, as: :calculator
      live "/profile/settings", Live.Profile.Settings, :index, as: :profile_settings
      live "/profile/settings/edit", Live.Profile, :edit, as: :profile_settings
      live "/calendar", Live.Calendar.Index, :index
      live "/calendar/settings", Live.Calendar.Settings, :settings
      get "/calendar-feed", CalendarFeedController, :index

      scope "/galleries/:id", GalleryLive do
        live "/", PhotographerIndex, :index
        live "/photos", Photos.Index, :index
        live "/product-previews", ProductPreview.Index, :index
        live "/orders", PhotographerOrders, :orders
      end

      scope "/galleries/:id/albums", GalleryLive do
        live "/", Albums.Index, :index
        live "/:album_id", Photos.Index, :index
      end

      live "/home", HomeLive.Index, :index, as: :home
      live "/leads/:id", LeadLive.Show, :leads, as: :job
      live "/leads", JobLive.Index, :leads, as: :job
      live "/jobs/:id", JobLive.Show, :jobs, as: :job
      live "/jobs/:id/transactions", JobLive.Transaction.Index, :transactions, as: :transaction

      live "/jobs/:id/transactions/:order_number", JobLive.Transaction.OrderDetail, :transactions,
        as: :order_detail

      live "/jobs", JobLive.Index, :jobs, as: :job
      live "/jobs/:id/shoot/:shoot_number", JobLive.Shoot, :jobs, as: :shoot
      live "/leads/:id/shoot/:shoot_number", JobLive.Shoot, :leads, as: :shoot

      live "/inbox", InboxLive.Index, :index, as: :inbox
      live "/inbox/:id", InboxLive.Index, :show, as: :inbox

      live "/onboarding", OnboardingLive.Index, :index, as: :onboarding
    end
  end

  scope "/photographer/embed", PicselloWeb do
    pipe_through [:browser_iframe]

    get "/:organization_slug", LeadContactIframeController, :index
    post "/:organization_slug", LeadContactIframeController, :create
  end

  scope "/", PicselloWeb do
    pipe_through [:browser]

    get "/calendar/:token", ICalendarController, :index

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm

    live "/proposals/:token", BookingProposalLive.Show, :show, as: :booking_proposal
    live "/photographer/:organization_slug", Live.Profile, :index, as: :profile

    live "/gallery-expired/:hash", GalleryLive.ClientShow.GalleryExpire, :show
  end

  scope "/gallery/:hash", PicselloWeb do
    live_session :gallery_client, on_mount: {PicselloWeb.LiveAuth, :gallery_client} do
      pipe_through :browser

      scope "/" do
        pipe_through :param_auth
        live "/", GalleryLive.ClientIndex, :index
        live "/album/:album_id", GalleryLive.ClientAlbum, :album
        get "/zip", GalleryDownloadsController, :download_all
        get "/photos/:photo_id/download", GalleryDownloadsController, :download_photo
      end

      scope "/orders" do
        live "/", GalleryLive.ClientOrders, :show

        scope "/:order_number" do
          scope "/" do
            pipe_through :param_auth
            live "/", GalleryLive.ClientOrder, :show
          end

          live "/paid", GalleryLive.ClientOrder, :paid
        end
      end

      live "/cart", GalleryLive.ClientShow.Cart, :cart
      live "/cart/address", GalleryLive.ClientShow.Cart, :address
      post "/login", GallerySessionController, :post
    end
  end

  scope "/gallery/:hash", PicselloWeb do
    pipe_through [:api]

    # WHCC secondary action
    post "/", GalleryAddAndClone, :post
  end

  scope "/gallery", PicselloWeb do
    live_session :gallery_client_login, on_mount: {PicselloWeb.LiveAuth, :gallery_client_login} do
      pipe_through [:browser]

      live "/:hash/login", GalleryLive.ClientShow.Login, :login
    end
  end
end
