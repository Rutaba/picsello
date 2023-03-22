defmodule PicselloWeb.GalleryLive.Settings.ManageGalleryAnalyticsComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias PicselloWeb.GalleryLive.Shared, as: GalleryLiveShared

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(gallery_analytics: assign_unique_emails_list(assigns.gallery.gallery_analytics))
    |> ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3>Gallery analytics</h3>
        <div class="flex justify-between">
          <p class="font-sans text-base-250">You can see if your client has logged into the gallery or send a reminder!</p>
        </div>
        <div class="flex flex-col mt-2">
          <p class="font-bold">Emails that have viewed:</p>
          <%= if @gallery_analytics != [] do %>
            <%= for gallery_analytic <- @gallery_analytics do %>
            <div class="flex flex-row mt-2 items-center">
              <div class="flex">
                <div class="flex items-center justify-center flex-shrink-0 w-8 h-8 rounded-full bg-blue-planning-300">
                  <.icon name="envelope" class="w-4 h-4 text-white fill-current"/>
                </div>
              </div>
              <div class="flex flex-col ml-2">
                <p class="text-base-250 font-bold"><%= gallery_analytic["email"] <> " (client)" %></p>
                <p class="text-base-250 font-normal">Viewed: <%= format_date_string(gallery_analytic["viewed_at"]) %></p>
              </div>
            </div>
            <% end %>
          <% else %>
            <p class="text-base-250">No one has viewed yet!</p>
          <% end %>
        </div>
        <div {testid("send-reminder")} class="flex flex-row-reverse items-center justify-between w-full mt-5 lg:items-start">
            <a class={classes("btn-settings px-5 hover:cursor-pointer", %{"hidden" => @gallery_analytics != []})} phx-click="client-link">Send reminder</a>
        </div>
    </div>
    """
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: GalleryLiveShared

  defp assign_unique_emails_list(gallery_analytics) do
    (gallery_analytics || [])
    |> Enum.sort_by(& &1["viewed_at"], &>=/2)
    |> Enum.uniq_by(& &1["email"])
  end

  defp format_date_string(date_string) do
    date =
      date_string
      |> String.slice(0..9)
      |> String.split("-")

    [year, month, day] = date

    "#{day}/#{month}/#{String.slice(year, 2..3)}"
  end
end
