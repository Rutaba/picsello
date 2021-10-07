defmodule PicselloWeb.LayoutView do
  use PicselloWeb, :view
  alias Picsello.Accounts.User
  import PicselloWeb.LiveHelpers, only: [icon: 1]

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
      {:error, "warning-white", "bg-red-invalid-bg", "bg-red-invalid", "text-red-invalid",
       "border-red-invalid"},
      {:info, "info", "bg-blue-light-primary", "bg-blue-primary", "text-blue-primary",
       "border-blue-primary"},
      {:success, "checkmark", "bg-green-light", "bg-green", "text-green", "border-green"}
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

  def side_nav(socket),
    do: [
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{title: "Jobs", icon: "camera-check", path: Routes.job_path(socket, :jobs)},
      %{title: "Orders", icon: "cart", path: "#"},
      %{title: "Calendar", icon: "calendar", path: "#"},
      %{title: "Inbox", icon: "envelope", path: "#"},
      %{title: "Marketing", icon: "bullhorn", path: "#"},
      %{title: "Contacts", icon: "phone", path: "#"},
      %{title: "Finances", icon: "money-bags", path: "#"},
      %{title: "Settings", icon: "gear", path: Routes.user_settings_path(socket, :edit)},
      %{title: "Help", icon: "question-mark", path: "#"}
    ]

  def top_nav(socket),
    do: [
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{title: "Finances", icon: "money-bags", path: "#"},
      %{title: "Help", icon: "question-mark", path: "#"},
      %{title: "Settings", icon: "gear", path: Routes.user_settings_path(socket, :edit)}
    ]

  def path_active?(
        %{
          view: socket_view,
          router: router,
          host_uri: %{host: host}
        },
        socket_live_action,
        path
      ),
      do:
        match?(
          %{phoenix_live_view: {view, live_action, _, _}}
          when view == socket_view and live_action == socket_live_action,
          Phoenix.Router.route_info(router, "GET", path, host)
        )
end
