defmodule PicselloWeb.ClientBookingEventLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.BookingEvents

  import PicselloWeb.Live.Profile.Shared,
    only: [
      assign_organization_by_slug_on_profile_disabled: 2,
      photographer_logo: 1,
      profile_footer: 1
    ]

  import PicselloWeb.ClientBookingEventLive.Shared,
    only: [
      blurred_thumbnail: 1,
      subtitle_display: 1,
      date_display: 1,
      address_display: 1,
      maybe_event_disable_or_archive: 1
    ]

  @impl true
  def mount(%{"organization_slug" => slug, "id" => event_id} = params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_organization_by_slug_on_profile_disabled(slug)
    |> assign_booking_event(event_id)
    |> maybe_show_expired_message(params)
    |> maybe_event_disable_or_archive()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @status == :active do %>
      <div class="center-container px-8 pt-6 mx-auto min-h-screen flex flex-col">
        <div class="flex">
          <.photographer_logo class="font-normal" organization={@organization} />
        </div>
        <hr class="border-gray-100 my-8">

        <div class="flex flex-col-reverse sm:flex-row">
          <div class="flex-1 sm:pr-8">
            <div class="flex flex-col pt-8 sm:max-w-lg">
              <h1 class="text-4xl"><%= @booking_event.name %></h1>
              <p class="text-base-250 mt-2 text-lg"><%= Picsello.Package.price(@booking_event.package_template) %></p>
              <.subtitle_display booking_event={@booking_event} package={@booking_event.package_template} class="text-base-250 mt-2" />
              <div class="mt-4 flex flex-col border-gray-100 border-y py-4 text-base-250">
                <%= Enum.map(@booking_event.dates, fn booking_event_date -> %>
                  <.date_display date={date_formatter(booking_event_date.date)} />
                  <.address_display booking_event={booking_event_date} class="mb-4" />
                <% end) %>
              </div>
              <div class="mt-4 raw_html"><%= raw @booking_event.description %></div>
              <.live_link to={Routes.client_booking_event_path(@socket, :booked, @organization.slug, @booking_event.id)} class="btn-primary text-center mt-12">Book now</.live_link>
            </div>
          </div>
          <.blurred_thumbnail class="w-full flex-1" url={@booking_event.thumbnail_url} />
        </div>

        <hr class="border-gray-100 mt-8 sm:mt-20">

        <.profile_footer color={@color} photographer={@photographer} organization={@organization} />
      </div>
      <% else %>
      <div class="center-container px-8 pt-6 mx-auto min-h-screen flex flex-col">
        <h1 class="text-1x text-center font-bold"> No available times </h1>
      </div>
    <% end %>
    """
  end

  defp assign_booking_event(%{assigns: %{organization: organization}} = socket, event_id) do
    booking_event =
      BookingEvents.get_preloaded_booking_event!(organization.id, event_id)
      |> BookingEvents.sorted_booking_event()

    title = "#{booking_event.name} | Book with #{organization.name}"
    description = HtmlSanitizeEx.strip_tags(booking_event.description)

    socket
    |> assign(booking_event: booking_event)
    |> assign(:page_title, title)
    |> assign(:meta_attrs, %{
      description: description,
      "og:title": title,
      "og:description": description,
      "og:image": booking_event.thumbnail_url,
      "og:url":
        "https://app.picsello.com#{Routes.client_booking_event_path(socket, :show, organization.slug, booking_event.id)}",
      "og:type": "website"
    })
  end

  defp maybe_show_expired_message(socket, %{"booking_expired" => "true"}),
    do:
      socket
      |> PicselloWeb.ConfirmationComponent.open(%{
        title: "Your reservation has expired. You'll have to start over.",
        icon: "warning-orange"
      })

  defp maybe_show_expired_message(socket, _), do: socket
end
