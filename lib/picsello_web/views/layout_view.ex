defmodule PicselloWeb.LayoutView do
  use PicselloWeb, :view

  alias Picsello.Accounts.User

  import PicselloWeb.LiveHelpers,
    only: [
      testid: 1,
      classes: 2,
      icon: 1,
      nav_link: 1,
      classes: 1,
      initials_circle: 1,
      help_scout_output: 2
    ]

  import Picsello.Profiles, only: [public_url: 1]
  import PicselloWeb.Live.Profile.Shared, only: [photographer_logo: 1]
  import PicselloWeb.Shared.StickyUpload, only: [sticky_upload: 1, gallery_top_banner: 1]

  use Phoenix.Component

  defp default_meta_tags do
    for(
      {meta_name, config_key} <- %{
        "google-site-verification" => :google_site_verification,
        "google-maps-api-key" => :google_maps_api_key
      },
      reduce: %{}
    ) do
      acc ->
        case Application.get_env(:picsello, config_key) do
          nil -> acc
          value -> Map.put(acc, meta_name, value)
        end
    end
  end

  def meta_tags(nil) do
    meta_tags(%{})
  end

  def meta_tags(attrs_list) do
    Map.merge(default_meta_tags(), attrs_list)
  end

  defp flash_styles,
    do: [
      {:error, "error", "text-red-sales-300"},
      {:info, "info", "text-blue-planning-300"},
      {:success, "tick", "text-green-finances-300"}
    ]

  def flash(flash) do
    assigns = %{flash: flash}

    ~H"""
    <div>
      <%= for {key, icon, text_color} <- flash_styles(), message <- [live_flash(@flash, key)], message do %>
        <%= if(key in [:error, :info, :success])  do %>
        <div phx-hook="Flash" id={"flash-#{DateTime.to_unix(DateTime.utc_now)}"} phx-click="lv:clear-flash" phx-value-key={key} title={key} class="fixed right-10-md right-0 top-1.5 z-30 max-w-lg px-1.5 px-0-md" role="alert">
          <div class="flex bg-white rounded-lg shadow-lg cursor-pointer">
            <div class={classes(["flex items-center justify-center p-3", text_color])}>
              <.icon name={icon} class="w-6 h-6 stroke-current" />
            </div>
            <div class="flex items-center justify-center font-sans flex-grow px-3 py-2 mr-7">
              <p><%= message %></p>
            </div>
            <div class="flex items-center justify-center mr-3">
              <.icon name="close-x" class="w-3 h-3 stroke-current" />
            </div>
          </div>
        </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def google_analytics(assigns) do
    ~H"""
    <!-- Global site tag (gtag.js) - Google Analytics -->
    <script async src={"https://www.googletagmanager.com/gtag/js?id=#{@gaId}"}></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());

      gtag('config', '<%= @gaId %>');
    </script>
    """
  end

  def google_tag_manager(assigns) do
    ~H"""
    <!-- Google Tag Manager -->
    <script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
    new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
    j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
    'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
    })(window,document,'script','dataLayer','<%= @gtmId %>');</script>
    <!-- End Google Tag Manager -->

    <!-- Google Tag Manager (noscript) -->
    <noscript><iframe src={"https://www.googletagmanager.com/ns.html?id=#{@gtmId}"}
    height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>
    <!-- End Google Tag Manager (noscript) -->
    """
  end

  def help_scout_menu(assigns) do
    ~H"""
    <%= if @current_user && Application.get_env(:picsello, :help_scout_id) && Application.get_env(:picsello, :help_scout_id_business)  do %>
    <div id="float-menu-help" class="hidden cursor-pointer md:blockhidden md:block" phx-update="ignore" phx-hook="ToggleContent">
      <div class="fixed flex items-center justify-center text-white rounded-full bg-blue-planning-300 help-scout-facade-circle">
        <.icon name="question-mark-help-scout" class="w-6 h-6" />
      </div>
      <div class="fixed top-0 bottom-0 left-0 right-0 flex flex-col items-end justify-end hidden bg-base-300/60 toggle-content">
        <nav class="flex flex-col w-64 ml-8 mr-16 overflow-hidden bg-white rounded-lg shadow-md my-11">
          <a href="#" class="flex items-center px-2 py-2 m-4 mb-0 border border-white rounded-lg hover:border hover:border-blue-planning-300" {help_scout_output(@current_user, :help_scout_id)}>
            <.icon name="question-mark" class="inline-block w-5 h-5 mr-2 text-blue-planning-300" />
            Help Center
          </a>
          <a href="#" class="flex items-center px-2 py-2 m-4 border border-white rounded-lg hover:border hover:border-blue-planning-300" {help_scout_output(@current_user, :help_scout_id_business)}>
            <.icon name="camera-laptop" class="inline-block w-5 h-5 mr-2 text-blue-planning-300" />
            Business Coaching
          </a>
          <div class="p-4 pl-12 text-sm text-white uppercase bg-blue-planning-300">
          Help
          </div>
        </nav>
        <div class="fixed flex items-center justify-center text-white rounded-full bg-blue-planning-300 help-scout-facade-circle">
          <.icon name="close-x" class="w-6 h-6 stroke-current stroke-2" />
        </div>
      </div>
    </div>
    <% end %>
    """
  end

  def side_nav(socket, _current_user) do
    [
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{title: "Jobs", icon: "camera-check", path: Routes.job_path(socket, :jobs)},
      %{
        title: "Galleries",
        icon: "proof_notifier",
        path: Routes.gallery_path(socket, :galleries)
      },
      %{title: "Orders", icon: "cart"},
      %{title: "Inbox", icon: "envelope", path: Routes.inbox_path(socket, :index)},
      %{title: "Marketing", icon: "bullhorn", path: Routes.marketing_path(socket, :index)},
      %{title: "Contacts", icon: "phone", path: Routes.contacts_path(socket, :index)},
      %{
        title: "Finances",
        icon: "money-bags",
        path: Routes.finance_settings_path(socket, :index)
      },
      %{title: "Settings", icon: "gear", path: Routes.user_settings_path(socket, :edit)},
      %{
        title: "Public profile",
        icon: "profile",
        path: Routes.profile_settings_path(socket, :index)
      },
      %{
        title: "Business Coaching",
        icon: "camera-laptop",
        path: "#business-coaching"
      },
      %{
        title: "Help",
        icon: "question-mark",
        path: "https://support.picsello.com/"
      }
    ]
    |> Enum.filter(&Map.get(&1, :path))
  end

  def top_nav(socket),
    do: [
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{
        title: "Calendar",
        icon: "calendar",
        path: Routes.calendar_index_path(socket, :index)
      },
      %{title: "Help", icon: "question-mark", path: "https://support.picsello.com/"},
      %{title: "Settings", icon: "gear", path: Routes.user_settings_path(socket, :edit)}
    ]

  def subscription_ending_soon(%{current_user: current_user} = assigns) do
    subscription = current_user |> Picsello.Subscriptions.subscription_ending_soon_info()

    case assigns.type do
      "banner" ->
        ~H"""
        <div {testid("subscription-top-banner")} class={classes(@class, %{"hidden" => subscription.hidden?})}>
          <.icon name="clock-filled" class="lg:w-5 lg:h-5 w-8 h-8 mr-2"/>
          <span>You have <%= ngettext("1 day", "%{count} days", Map.get(subscription, :days_left, 0)) %> left before your subscription ends.
            <%= live_redirect to: Routes.user_settings_path(@socket, :edit), title: "Click here" do %>
              <span class="font-bold underline px-1 cursor-pointer">Click here</span>
            <% end %>
            to upgrade.
          </span>
        </div>
        """

      _ ->
        ~H"""
        <div {testid("subscription-footer")} class={classes(@class, %{"hidden" => subscription.hidden?})}>
          <%= live_redirect to: Routes.user_settings_path(@socket, :edit) do %>
            <%= ngettext("1 day", "%{count} days", Map.get(subscription, :days_left, 0)) %> left until your subscription ends
          <% end %>
        </div>
        """
    end
  end

  defp footer_nav(assigns) do
    organization = load_organization(assigns.gallery)

    ~H"""
    <nav class="flex text-lg font-bold">
      <div class="font-bold">
        <.photographer_logo organization={organization} />
      </div>
      <div class="ml-auto pt-3">
        <a class="flex items-center justify-center px-2.5 py-1 text-base-300 bg-base-100 border border-base-300 hover:text-base-100 hover:bg-base-300" href={public_url(organization)}>
          <.icon name="envelope" class="mr-2 w-4 h-4 fill-current"/>
          Contact
        </a>
      </div>
    </nav>
    <hr class="my-8 opacity-40 border-base-300" />
    <div class="flex text-base-250 flex-col sm:flex-row">
      <div class="flex justify-center">© <%= DateTime.utc_now.year %> <span class="font-base-300 font-bold"><%= organization.name %></span>. All Rights Reserved</div>
      <div class="flex md:ml-auto justify-center">
        Powered by
        <a href="https://www.picsello.com/terms-conditions" class="underline ml-1" target="_blank" rel="noopener noreferrer"> <b>Picsello</b></a>
      </div>
    </div>
    """
  end

  defp load_organization(gallery) do
    gallery
    |> Picsello.Repo.preload([job: [client: :organization]], force: true)
    |> extract_organization()
  end

  defp extract_organization(%{job: %{client: %{organization: organization}}}), do: organization
end
