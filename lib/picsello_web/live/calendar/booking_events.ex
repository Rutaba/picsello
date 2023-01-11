defmodule PicselloWeb.Live.Calendar.BookingEvents do
  @moduledoc false
  use PicselloWeb, :live_view

  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import PicselloWeb.ClientBookingEventLive.Shared, only: [blurred_thumbnail: 1]
  alias Picsello.BookingEvents

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Booking Events")
    |> assign_booking_events()
    |> ok()
  end

  @impl true
  def handle_params(
        %{"duplicate" => event_id},
        _,
        %{assigns: %{live_action: :new, current_user: current_user}} = socket
      ) do
    socket
    |> open_wizard(%{
      booking_event:
        BookingEvents.get_booking_event!(current_user.organization_id, event_id)
        |> Map.put(:id, nil)
        |> Map.put(:inserted_at, nil)
        |> Map.put(:updated_at, nil)
        |> Map.put(:disabled_at, nil)
        |> Map.put(:__meta__, %Picsello.BookingEvent{} |> Map.get(:__meta__))
    })
    |> noreply()
  end

  @impl true
  def handle_params(_, _, %{assigns: %{live_action: :new}} = socket) do
    socket
    |> open_wizard()
    |> noreply()
  end

  @impl true
  def handle_params(
        %{"id" => event_id},
        _,
        %{
          assigns: %{
            live_action: :edit,
            current_user: current_user,
            booking_events: booking_events
          }
        } = socket
      ) do
    event_id = String.to_integer(event_id)

    if booking_events |> Enum.find(&(&1.id == event_id)) |> Map.get(:can_edit?) do
      socket
      |> open_wizard(%{
        booking_event: BookingEvents.get_booking_event!(current_user.organization_id, event_id)
      })
      |> noreply()
    else
      socket
      |> push_patch(to: Routes.calendar_booking_events_path(socket, :index), replace: true)
      |> noreply()
    end
  end

  @impl true
  def handle_params(_, _, socket) do
    socket |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pt-6 px-6 py-2 center-container">
      <div class="flex text-4xl items-center">
        <.back_button to={Routes.calendar_index_path(@socket, :index)} class="lg:hidden"/>
        <.crumbs class="text-base text-base-250">
          <:crumb to={Routes.calendar_index_path(@socket, :index)}>Calendar</:crumb>
          <:crumb>Booking events</:crumb>
        </.crumbs>
      </div>

      <hr class="mt-2 border-white" />

      <div class="flex items-center justify-between lg:mt-2 md:justify-start">
        <div class="flex text-4xl font-bold items-center">
          <.back_button to={Routes.calendar_index_path(@socket, :index)} class="hidden lg:flex mt-2"/>
          Booking events
        </div>
        <%= unless Enum.empty?(@booking_events) do %>
          <div class="fixed bottom-0 left-0 right-0 z-10 flex flex-shrink-0 w-full sm:p-0 p-6 mt-auto sm:mt-0 sm:bottom-auto sm:ml-auto sm:static sm:items-start sm:w-auto">
            <.live_link to={Routes.calendar_booking_events_path(@socket, :new)} class="w-full md:w-auto btn-primary text-center">
              Add booking event
            </.live_link>
          </div>
        <% end %>
      </div>

      <hr class="mt-4 sm:mt-10" />
    </div>

    <%= if Enum.empty?(@booking_events) do %>
      <div class="flex flex-col justify-between flex-auto mt-4 p-6 center-container lg:flex-none">
        <div class="flex flex-col">
          <h1 class="mt-3 mb-3 text-4xl font-bold lg:text-5xl">Oh hey!</h1>
          <p class="block text-lg lg:text-2xl lg:w-1/2">You don’t have any booking events created at the moment. Booking events allow you to create events and pages to send to your clients so they can sign up for mini-sessions shoots.</p>
        </div>
        <div class="lg:inline-flex">
          <.live_link to={Routes.calendar_booking_events_path(@socket, :new)} class="flex justify-center mt-5 text-lg px-7 btn-primary">
            Add booking event
          </.live_link>
        </div>
      </div>
    <% else %>
      <div class="p-6 center-container">
        <div class="hidden sm:grid sm:grid-cols-4 gap-2 border-b-8 border-blue-planning-300 font-semibold text-lg pb-6">
          <div class="sm:col-span-2">Event Details</div>
          <div>Bookings so far</div>
          <div>Actions</div>
        </div>
        <%= for event <- @booking_events do %>
          <div class="grid sm:grid-cols-4 gap-2 border p-3 sm:pt-0 sm:px-0 sm:pb-4 sm:border-b sm:border-t-0 sm:border-x-0 rounded-lg sm:rounded-none border-gray-100 mt-4">
            <.details_cell booking_event={event} />
            <hr class="sm:hidden border-gray-100 my-2" />
            <.bookings_cell booking_event={event} />
            <hr class="sm:hidden border-gray-100 my-2" />
            <.actions_cell booking_event={event} />
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp details_cell(assigns) do
    ~H"""
    <div class="sm:col-span-2 grid sm:flex gap-2 sm:gap-0">
      <.blurred_thumbnail class="h-32 rounded-lg" url={@booking_event.thumbnail_url} />
      <div class="flex flex-col items-start justify-center sm:ml-4">
        <%= if @booking_event.disabled_at do %>
          <.badge color={:gray}>Disabled</.badge>
        <% else %>
          <p class="font-semibold"><%= @booking_event.date |> Calendar.strftime("%m/%d/%Y") %></p>
        <% end %>
        <p class="text-xl font-semibold"><%= @booking_event.name %></p>
        <p class="text-gray-400"><%= @booking_event.package_name %></p>
        <p class="text-gray-400"><%= @booking_event.duration_minutes %> minutes</p>
      </div>
    </div>
    """
  end

  defp bookings_cell(assigns) do
    ~H"""
    <div class="flex flex-col justify-center">
      <p><%= ngettext("%{count} booking", "%{count} bookings", @booking_event.booking_count) %> so far</p>
    </div>
    """
  end

  defp actions_cell(assigns) do
    ~H"""
    <div class="flex items-center justify-start">
      <.icon_button icon="eye" disabled={!!@booking_event.disabled_at} color="blue-planning-300" class="flex-1 sm:flex-none justify-center transition-colors text-blue-planning-300" href={@booking_event.url} target="_blank" rel="noopener noreferrer">
        Preview
      </.icon_button>
      <.icon_button icon="anchor" disabled={!!@booking_event.disabled_at} color="blue-planning-300" class="ml-2 flex-1 sm:flex-none justify-center transition-colors text-blue-planning-300" id={"copy-event-link-#{@booking_event.id}"} data-clipboard-text={@booking_event.url} phx-hook="Clipboard">
        <span>Copy link</span>
        <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
          Copied!
        </div>
      </.icon_button>
      <div phx-update="ignore" data-offset="0" phx-hook="Select" id={"manage-event-#{@booking_event.id}-#{!!@booking_event.disabled_at}"}>
        <button title="Manage" type="button" class="flex flex-shrink-0 ml-2 p-2.5 bg-white border rounded-lg border-blue-planning-300 text-blue-planning-300">
          <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />
          <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
        </button>

        <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content">
          <button disabled={!@booking_event.can_edit?} title={if @booking_event.can_edit?, do: "Edit", else: "Can't edit a booking event that has leads already"} type="button" {if @booking_event.can_edit?, do: %{phx_click: "edit-event", phx_value_event_id: @booking_event.id}, else: %{}}
                  class={classes("flex items-center px-3 py-2 rounded-lg", %{"hover:bg-blue-planning-100 hover:font-bold" => @booking_event.can_edit?, "opacity-40 cursor-not-allowed" => !@booking_event.can_edit?})}
          >
            <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
            Edit
          </button>

          <button title="Duplicate" type="button" phx-click="duplicate-event" phx-value-event-id={@booking_event.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
            <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
            Duplicate
          </button>

          <%= if @booking_event.disabled_at do %>
            <button title="Enable" type="button" phx-click="enable-event" phx-value-event-id={@booking_event.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name="eye" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
              Enable
            </button>
          <% else %>
            <button title="Disable" type="button" phx-click="confirm-disable-event" phx-value-event-id={@booking_event.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
              <.icon name="closed-eye" class="inline-block w-4 h-4 mr-3 fill-current text-red-sales-300" />
              Disable
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("edit-event", %{"event-id" => id}, socket) do
    socket
    |> push_patch(to: Routes.calendar_booking_events_path(socket, :edit, id))
    |> noreply()
  end

  @impl true
  def handle_event("duplicate-event", %{"event-id" => id}, socket) do
    socket
    |> push_patch(to: Routes.calendar_booking_events_path(socket, :new, duplicate: id))
    |> noreply()
  end

  @impl true
  def handle_event("confirm-disable-event", %{"event-id" => id}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      title: "Disable this event?",
      subtitle: """
      Disabling this event will hide all availability for this event and prevent any further booking. This is also the first step to take if you need to cancel an event for any reason.
      Some things to keep in mind:
        • If you are no longer able to shoot at the date and time provided, let your clients know. We suggest offering them a new link to book with once you reschedule!
        • You may need to refund any payments made to prevent confusion with your clients.
        • Archive each job individually in the Jobs page if you intend to cancel it.
        • Reschedule if possible to keep business coming in!
      """,
      confirm_event: "disable_event_" <> id,
      confirm_label: "Disable Event",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "enable-event",
        %{"event-id" => id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.enable_booking_event(id, current_user.organization_id) do
      {:ok, _event} ->
        socket
        |> assign_booking_events()
        |> put_flash(:success, "Event enabled successfully")
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:success, "Error enabling event")
        |> noreply()
    end
  end

  @impl true
  def handle_info(
        {:confirm_event, "disable_event_" <> id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.disable_booking_event(id, current_user.organization_id) do
      {:ok, _event} ->
        socket
        |> close_modal()
        |> assign_booking_events()
        |> put_flash(:success, "Event disabled successfully")
        |> noreply()

      {:error, _} ->
        socket
        |> close_modal()
        |> put_flash(:success, "Error disabling event")
        |> noreply()
    end
  end

  @impl true
  def handle_info({:update, %{booking_event: _booking_event}}, socket) do
    socket
    |> assign_booking_events()
    |> put_flash(:success, "Booking event saved successfully")
    |> noreply()
  end

  @impl true
  def handle_info({:wizard_closed, _modal}, %{assigns: assigns} = socket) do
    assigns
    |> Map.get(:flash, %{})
    |> Enum.reduce(socket, fn {kind, msg}, socket -> put_flash(socket, kind, msg) end)
    |> push_patch(to: Routes.calendar_booking_events_path(socket, :index))
    |> noreply()
  end

  defp open_wizard(socket, assigns \\ %{}) do
    socket
    |> open_modal(PicselloWeb.Live.Calendar.BookingEventWizard, %{
      close_event: :wizard_closed,
      assigns: Enum.into(assigns, Map.take(socket.assigns, [:current_user]))
    })
  end

  defp assign_booking_events(%{assigns: %{current_user: current_user}} = socket) do
    booking_events =
      BookingEvents.get_booking_events(current_user.organization_id)
      |> Enum.map(fn booking_event ->
        booking_event
        |> Map.put(:date, booking_event.dates |> hd |> Map.get(:date))
        |> Map.drop([:dates])
        |> Map.put(
          :url,
          Routes.client_booking_event_url(
            socket,
            :show,
            current_user.organization.slug,
            booking_event.id
          )
        )
      end)
      |> Enum.sort_by(& &1.date, {:asc, Date})

    socket
    |> assign(booking_events: booking_events)
  end
end
