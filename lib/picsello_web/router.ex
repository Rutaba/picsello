defmodule PicselloWeb.Router do
  alias PicselloWeb.UserAdminSessionController
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

  pipeline :calendar do
    plug :accepts, ["html", "text/calendar"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PicselloWeb.LayoutView, :root}
    plug :put_secure_browser_headers
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
    live "/shipment_details", Live.Admin.Shippment.Index, :index
    live "/categories", Live.Admin.Categories, :index
    live "/pricing_calculator", Live.Admin.PricingCalculator, :index
    live "/next_up_cards", Live.Admin.NextUpCards, :index
    live "/subscription_pricing", Live.Admin.SubscriptionPricing, :index
    live "/product_pricing", Live.Admin.ProductPricing, :index
    live "/product_pricing/:id", Live.Admin.ProductPricing, :show
    live "/user", Live.Admin.User.Index, :index
    live "/user/:id/contact_upload", Live.Admin.User.ContactUpload, :show
    live "/workers", Live.Admin.Workers, :index
    live "/", Live.Admin.Index, :index
    post "/users/log_in", UserAdminSessionController, :create
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
      live "/brand", Live.BrandSettings, :index, as: :brand_settings
      live "/finance", Live.FinanceSettings, :index, as: :finance_settings
      live "/marketing", Live.Marketing, :index, as: :marketing
      live "/users/settings", Live.User.Settings, :edit
      live "/galleries/settings", GalleryLive.GlobalSettings.Index, :edit
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
      live "/booking-events", Live.Calendar.BookingEvents.Index, :index
      live "/booking-events/:id", Live.Calendar.BookingEvents.Show, :edit
      live "/booking-events/:id/edit", Live.Calendar.BookingEvents, :edit
      live "/questionnaires", Live.Questionnaires.Index, :index
      get "/calendar-feed", CalendarFeedController, :index
      get "/calendar-feed/:id", CalendarFeedController, :show

      scope "/galleries/:id", GalleryLive do
        live "/", PhotographerIndex, :index
        live "/photos", Photos.Index, :index
        live "/pricing", Pricing.Index, :index
        live "/product-previews", ProductPreview.Index, :index
        live "/orders", PhotographerOrders, :orders

        live "/transactions", Transaction.Index, :transactions, as: :transaction

        live "/transactions/:order_number",
             Transaction.OrderDetail,
             :transactions,
             as: :order_detail
      end

      scope "/galleries/:id/albums", GalleryLive do
        live "/", Albums.Index, :index
        live "/:album_id", Photos.Index, :index
      end

      live "/galleries", GalleryLive.Index, :galleries, as: :gallery

      live "/home",
           HomeLive.Index,
           :index,
           as: :home

      live "/leads/:id", LeadLive.Show, :leads, as: :job
      live "/leads", JobLive.Index, :leads, as: :job
      live "/jobs/:id", JobLive.Show, :jobs, as: :job

      live "/jobs", JobLive.Index, :jobs, as: :job
      live "/jobs/:id/shoot/:shoot_number", JobLive.Shoot, :jobs, as: :shoot
      live "/leads/:id/shoot/:shoot_number", JobLive.Shoot, :leads, as: :shoot

      scope "/clients", Live.ClientLive do
        live "/", Index, :index, as: :clients
        live "/:id", Show, :show, as: :client
        live "/:id/job-history", JobHistory, :job_history, as: :client
        live "/:id/order-history", OrderHistory, :order_history, as: :client
      end

      live "/inbox", InboxLive.Index, :index, as: :inbox
      live "/inbox/:id", InboxLive.Index, :show, as: :inbox

      live "/contracts", Live.Contracts.Index, :index

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

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm

    live "/proposals/:token", BookingProposalLive.Show, :show, as: :booking_proposal
    live "/photographer/:organization_slug", Live.Profile, :index, as: :profile

    live "/photographer/:organization_slug/event/:id", ClientBookingEventLive.Show, :show,
      as: :client_booking_event

    live "/photographer/:organization_slug/event/:id/book", ClientBookingEventLive.Book, :book,
      as: :client_booking_event

    live "/gallery-expired/:hash", GalleryLive.ClientShow.GalleryExpire, :show

    get "/jobs/:id/booking_proposals/:booking_proposal_id",
        JobDownloadController,
        :download_invoice_pdf
  end

  scope "/gallery/:hash", PicselloWeb do
    live_session :gallery_client, on_mount: {PicselloWeb.LiveAuth, :gallery_client} do
      pipe_through :browser

      scope "/" do
        pipe_through :param_auth
        live "/", GalleryLive.ClientIndex, :index
        live "/album/:album_id", GalleryLive.ClientAlbum, :album
        live "/cards", GalleryLive.CardEditor, :index
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
          get "/csv", GalleryDownloadsController, :download_csv
        end
      end

      live "/cart", GalleryLive.ClientShow.Cart, :cart
      live "/cart/address", GalleryLive.ClientShow.Cart, :address
      post "/gallery/login", GallerySessionController, :gallery_login
    end
  end

  scope "/album/:hash", PicselloWeb do
    pipe_through [:browser]

    live_session :proofing_album_client, on_mount: {PicselloWeb.LiveAuth, :proofing_album_client} do
      live "/", GalleryLive.ClientAlbum, :proofing_album

      live "/cart", GalleryLive.ClientShow.Cart, :proofing_album
      live "/cart/address", GalleryLive.ClientShow.Cart, :proofing_album_address

      live "/cards", GalleryLive.CardEditor, :finals_album

      scope "/orders" do
        live "/", GalleryLive.ClientOrders, :proofing_album
        live "/:order_number", GalleryLive.ClientOrder, :proofing_album
        live "/:order_number/paid", GalleryLive.ClientOrder, :proofing_album_paid
      end
    end

    live_session :proofing_album_client_login,
      on_mount: {PicselloWeb.LiveAuth, :proofing_album_client_login} do
      live "/login", GalleryLive.ClientShow.Login, :album_login
    end
  end

  scope "/calendar/:token", PicselloWeb do
    pipe_through [:calendar]

    get "/", ICalendarController, :index
  end

  scope "/gallery/:hash", PicselloWeb do
    pipe_through [:api]

    # WHCC secondary action
    post "/", GalleryAddAndClone, :post
  end

  scope "/gallery", PicselloWeb do
    live_session :gallery_client_login, on_mount: {PicselloWeb.LiveAuth, :gallery_client_login} do
      pipe_through [:browser]

      live "/:hash/login", GalleryLive.ClientShow.Login, :gallery_login
    end
  end
end
