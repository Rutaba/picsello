defmodule PicselloWeb.ClientBookingEventLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.BookingEvents

  import PicselloWeb.Live.Profile.Shared,
    only: [
      assign_organization_by_slug: 2,
      photographer_logo: 1,
      profile_footer: 1
    ]

  import PicselloWeb.ClientBookingEventLive.Shared, only: [blurred_thumbnail: 1]

  @impl true
  def mount(%{"organization_slug" => slug, "id" => event_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_organization_by_slug(slug)
    |> assign_booking_event(event_id)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="center-container px-8 pt-6 mx-auto min-h-screen flex flex-col">
      <div class="flex">
        <.photographer_logo organization={@organization} />
      </div>
      <hr class="border-gray-100 my-8">

      <div class="flex flex-col-reverse sm:flex-row">
        <div class="flex-1 sm:pr-8">
          <div class="flex flex-col pt-8 sm:max-w-lg">
            <h1 class="text-4xl font-bold"><%= @booking_event.name %></h1>
            <p class="text-base-250"><%= subtitle(@booking_event) %></p>
            <div class="mt-4 flex flex-col border-gray-100 border-y py-4">
              <div class="flex items-center">
                <.icon name="calendar" class="w-5 h-5" />
                <span class="ml-2 pt-1 text-base-250"><%= date_display(@booking_event) %></span>
              </div>
              <div class="flex items-center mt-4">
                <.icon name="pin" class="w-5 h-5" />
                <span class="ml-2 pt-1 text-base-250"><%= @booking_event.address %></span>
              </div>
            </div>
            <div class="mt-4 raw_html"><%= raw @booking_event.description %></div>
            <button class="btn-primary mt-12">Book now</button>
          </div>
        </div>
        <.blurred_thumbnail class="w-full flex-1" url={@booking_event.thumbnail_url} />
      </div>

      <hr class="border-gray-100 mt-8 sm:mt-20">

      <.profile_footer color={@color} photographer={@photographer} organization={@organization} />
    </div>
    """
  end

  defp assign_booking_event(%{assigns: %{organization: organization}} = socket, event_id) do
    socket
    |> assign(booking_event: BookingEvents.get_booking_event!(organization.id, event_id))
  end

  defp subtitle(booking_event) do
    [
      if(booking_event.package_template.download_count > 0,
        do: "#{booking_event.package_template.download_count} images include"
      ),
      "#{booking_event.duration_minutes} min session",
      dyn_gettext(booking_event.location)
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" | ")
  end

  defp date_display(booking_event) do
    dates =
      booking_event
      |> Map.get(:dates)
      |> Enum.map(& &1.date)
      |> Enum.sort()
      |> Enum.map(&Calendar.strftime(&1, "%b %d, %Y"))

    [
      Enum.at(dates, 0),
      Enum.at(dates, -1)
    ]
    |> Enum.uniq()
    |> Enum.join(" - ")
  end
end
