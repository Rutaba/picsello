defmodule PicselloWeb.LayoutView do
  use PicselloWeb, :view
  alias Picsello.Accounts.User

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
end
