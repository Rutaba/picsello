defmodule PicselloWeb.LayoutView do
  use PicselloWeb, :view
  alias Picsello.Accounts.User

  import PicselloWeb.LiveHelpers,
    only: [icon: 1, nav_link: 1, classes: 1, initials_circle: 1, help_scout_output: 2]

  use Phoenix.Component

  def meta_tags do
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

  defp flash_styles,
    do: [
      {:error, "warning-white", "bg-red-sales-100", "bg-red-sales-300", "text-red-sales-300",
       "border-red-sales-300"},
      {:info, "info", "bg-blue-planning-100", "bg-blue-planning-300", "text-blue-planning-300",
       "border-blue-planning-300"},
      {:photo_success, "tick", "bg-white", "bg-black", "text-black", "border-black"},
      {:success, "checkmark", "bg-green-finances-100", "bg-green-finances-300",
       "text-green-finances-300", "border-green-finances-300"}
    ]

  def flash(flash) do
    assigns = %{flash: flash}

    ~H"""
    <div>
      <%= for {key, icon, bg_light, bg_dark, text_color, border_color} <- flash_styles(), message <- [live_flash(@flash, key)], message do %>
        <%= if(key in [:error, :info, :success])  do %>
        <div class="center-container">
          <div class={classes(["mx-6 font-bold rounded-lg cursor-pointer m-4 flex border-2", bg_light, text_color, border_color])} role="alert" phx-click="lv:clear-flash" phx-value-key={key} title={key}>
            <div class={classes(["flex items-center justify-center p-3", bg_dark])}>
              <PicselloWeb.LiveHelpers.icon name={icon} class="w-6 h-6 stroke-current" />
            </div>

            <div class="flex-grow p-3"><%= message %></div>

            <div class={classes(["flex items-center justify-center mr-3", text_color])}}>
              <PicselloWeb.LiveHelpers.icon name="close-x" class="w-3 h-3 stroke-current" />
            </div>
          </div>
        </div>
        <% else %>
          <div phx-click="lv:clear-flash" phx-value-key={key} class={"fixed right-10 top-2 z-40"}>
            <div class="flex bg-white rounded-lg shadow-lg cursor-pointer">
              <div class="flex items-center justify-center pl-2 bg-white rounded-lg">
                <.icon name={icon} class="w-6 h-6 stroke-current text-green-finances-300" />
              </div>
              <div class="flex items-center justify-center font-sans flex-grow p-3"><%= message %></div>
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
    <div id="float-menu-help" class="cursor-pointer hidden md:blockhidden md:block" phx-hook="ToggleContent">
      <div class="fixed flex items-center justify-center text-white rounded-full bg-blue-planning-300 help-scout-facade-circle">
        <.icon name="question-mark-help-scout" class="w-6 h-6" />
      </div>
      <div class="fixed top-0 bottom-0 left-0 right-0 flex flex-col items-end justify-end hidden bg-base-300/60 toggle-content">
        <nav class="flex flex-col w-64 ml-8 mr-16 my-11 overflow-hidden bg-white rounded-lg shadow-md">
          <a href="#" class="flex items-center px-2 py-2 m-4 border border-white rounded-lg hover:border hover:border-blue-planning-300" {help_scout_output(@current_user, :help_scout_id)}>
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

  def side_nav(socket, current_user) do
    [
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{title: "Jobs", icon: "camera-check", path: Routes.job_path(socket, :jobs)},
      %{title: "Orders", icon: "cart"},
      %{title: "Calendar", icon: "calendar", path: Routes.calendar_path(socket, :index)},
      %{title: "Inbox", icon: "envelope", path: Routes.inbox_path(socket, :index)},
      %{title: "Marketing", icon: "bullhorn", path: Routes.marketing_path(socket, :index)},
      %{title: "Contacts", icon: "phone", path: Routes.contacts_path(socket, :index)},
      %{
        title: "Finances",
        icon: "money-bags",
        path: current_user.organization.stripe_account_id && "https://dashboard.stripe.com"
      },
      %{title: "Settings", icon: "gear", path: Routes.user_settings_path(socket, :edit)},
      %{title: "Help", icon: "question-mark", path: "https://support.picsello.com/"}
    ]
    |> Enum.filter(&Map.get(&1, :path))
  end

  def top_nav(socket),
    do: [
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{
        title: "Public profile",
        icon: "profile",
        path: Routes.profile_settings_path(socket, :index)
      },
      %{title: "Help", icon: "question-mark", path: "https://support.picsello.com/"},
      %{title: "Settings", icon: "gear", path: Routes.user_settings_path(socket, :edit)}
    ]
end
