defmodule PicselloWeb.LayoutView do
  use PicselloWeb, :view
  alias Picsello.Accounts.User
  import PicselloWeb.LiveHelpers, only: [icon: 1, nav_link: 1, classes: 1, initials_circle: 1]

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
      {:success, "checkmark", "bg-green-finances-100", "bg-green-finances-300",
       "text-green-finances-300", "border-green-finances-300"}
    ]

  def flash(flash) do
    assigns = %{flash: flash}

    ~H"""
    <div>
      <%= for {key, icon, bg_light, bg_dark, text_color, border_color} <- flash_styles(), message <- [live_flash(@flash, key)], message do %>
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

  def side_nav(socket, current_user) do
    [
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{title: "Jobs", icon: "camera-check", path: Routes.job_path(socket, :jobs)},
      %{title: "Orders", icon: "cart"},
      %{title: "Calendar", icon: "calendar"},
      %{title: "Inbox", icon: "envelope", path: Routes.inbox_path(socket, :index)},
      %{title: "Marketing", icon: "bullhorn", path: Routes.marketing_path(socket, :index)},
      %{title: "Contacts", icon: "phone", path: Routes.contacts_path(socket, :index)},
      %{
        title: "Finances",
        icon: "money-bags",
        path: current_user.organization.stripe_account_id && "https://dashboard.stripe.com"
      },
      %{title: "Settings", icon: "gear", path: Routes.user_settings_path(socket, :edit)},
      %{title: "Help", icon: "question-mark", path: "#"}
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
      %{title: "Help", icon: "question-mark", path: "#"},
      %{title: "Settings", icon: "gear", path: Routes.user_settings_path(socket, :edit)}
    ]
end
