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
    |> assign_events()
    |> assign_booking_events()
    |> ok()
  end

  defp assign_events(socket) do
    socket
    |> assign(:event_status, "all")
    |> assign(:sort_by, "name")
    |> assign(:sort_col, "name")
    |> assign(:sort_direction, "asc")
    |> assign(:search_phrase, nil)
    |> assign(:new_event, false)
    |> assign(current_focus: -1)
    |> assign_new(:selected_event, fn -> nil end)
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
        |> Map.put(:status, :active)
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

    booking_event = booking_events |> Enum.find(&(&1.id == event_id))

    if booking_event do
      socket
      |> open_wizard(%{
        booking_event: BookingEvents.get_booking_event!(current_user.organization_id, event_id),
        can_edit?: Map.get(booking_event, :can_edit?),
        booking_count: Map.get(booking_event, :booking_count)
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
        <.crumbs class="text-sm text-base-250">
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
        <div class="fixed bottom-0 left-0 right-0 z-10 flex flex-shrink-0 w-full sm:p-0 p-6 mt-auto sm:mt-0 sm:bottom-auto sm:ml-auto sm:static sm:items-start sm:w-auto">
          <.live_link to={Routes.calendar_booking_events_path(@socket, :new)} class="w-full md:w-auto btn-primary text-center">
            Add booking event
          </.live_link>
        </div>
      </div>

      <hr class="mt-4 sm:mt-10" />
    </div>
    <div class="p-6 center-container">
      <%= form_tag("#", [phx_change: :search, phx_submit: :submit]) do %>
        <div class="flex flex-col justify-between lg:items-center md:flex-row mb-10">
          <div class="relative flex md:w-1/4 w-full">
            <a class="absolute top-0 bottom-0 flex flex-row items-center justify-center overflow-hidden text-xs text-gray-400 left-2">
              <%= if @search_phrase do %>
                <span phx-click="clear-search" class="cursor-pointer">
                  <.icon name="close-x" class="w-4 ml-1 fill-current stroke-current stroke-2 close-icon text-blue-planning-300" />
                </span>
              <% else %>
                <.icon name="search" class="w-4 ml-1 fill-current" />
              <% end %>
            </a>
            <input disabled={!is_nil(@selected_event) || @new_event} type="text" class="form-control w-full text-input indent-6" id="search_phrase_input" name="search_phrase" value={"#{@search_phrase}"} phx-debounce="500" spellcheck="false" placeholder="Search booking events..." />
          </div>
          <div class="flex lg:ml-auto mt-2 lg:mt-0">
            <div class = "flex flex-col">
              <.select_dropdown sort_direction={@sort_direction} title="Filter" id="status" selected_option={@event_status} options_list={filter_options()}}/>
            </div>
            <div class= "flex flex-col ml-4">
              <.select_dropdown sort_direction={@sort_direction} title="Sort" id="sort-by" selected_option={@sort_by} options_list={sort_options()}/>
            </div>
          </div>
        </div>
      <% end %>
    </div>

    <%= if Enum.empty?(@booking_events) do %>
      <div class="flex flex-col items-center mt-4 p-6 lg:flex-none">
        <%= if @search_phrase || @event_status !== "all" do %>
          <p class="text-lg lg:text-2xl text-base-250">No events match your search or filters.</p>
        <% else %>
          <div class="p-6 center-container">
            <.empty_state_base tour_embed="https://demo.arcade.software/eOBqmup7RcW8EVmGpqrY?embed" headline="Meet Client Booking" eyebrow_text="Booking Events Product Tour" body="Accelerate your business growth with mini-sessions, portraits & more! Create a booking link that you can share and take tedious work out of booking" third_party_padding="calc(66.66666666666666% + 41px)">
              <.live_link to={Routes.calendar_booking_events_path(@socket, :new)} class="w-full md:w-auto btn-tertiary text-center flex-shrink-0">
                Add booking event
              </.live_link>
            </.empty_state_base>
          </div>
        <% end %>
    </div>
    <% else %>
      <div class="p-6 center-container">
        <div class="hidden sm:grid sm:grid-cols-5 gap-2 border-b-8 border-blue-planning-300 font-semibold text-lg pb-6">
          <div class="sm:col-span-2">Event Details</div>
          <div>Bookings so far</div>
          <div>Actions</div>
        </div>
        <%= for event <- @booking_events do %>
          <div class="grid lg:grid-cols-5 grid-cols-1 gap-2 border p-3 sm:pt-0 sm:px-0 sm:pb-4 sm:border-b sm:border-t-0 sm:border-x-0 rounded-lg sm:rounded-none border-gray-100 mt-4">
            <.details_cell booking_event={event} socket={assigns.socket} />
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

  defp select_dropdown(assigns) do
    ~H"""
    <h1 class="font-extrabold text-sm flex flex-col"><%= @title %></h1>
      <div class="flex">
        <div id="select" class={classes("relative w-40 border-grey border rounded-l-lg p-2 cursor-pointer", %{"rounded-lg" => @title == "Filter"})} data-offset-y="5" phx-hook="Select">
          <div class="flex flex-row items-center border-gray-700">
              <%= capitalize_per_word(String.replace(@selected_option, "_", " ")) %>
              <.icon name="down" class="w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 open-icon" />
              <.icon name="up" class="hidden w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 close-icon" />
          </div>
          <ul class={classes("absolute z-30 hidden mt-2 bg-white toggle rounded-md popover-content border border-base-200",%{"w-41" => @id == "status", "w-40" => @id=="sort-by"})}>
            <%= for option <- @options_list do %>
              <li id={option.id} target-class="toggle-it" parent-class="toggle" toggle-type="selected-active" phx-hook="ToggleSiblings"
              class="flex items-center py-1.5 hover:bg-blue-planning-100 hover:rounded-md">

                <button id={option.id} class="album-select w-40" phx-click={"apply-filter-#{@id}"} phx-value-option={option.id}><%= option.title %></button>
                <%= if option.id == @selected_option do %>
                  <.icon name="tick" class="w-6 h-5 mr-1 toggle-it text-green" />
                <% end %>
              </li>
            <% end %>
          </ul>
        </div>
        <%= if @title == "Sort" do%>
          <div class="items-center flex border rounded-r-lg border-grey p-2">
            <button phx-click="switch_sort">
              <.icon name={if @sort_direction == "asc", do: "sort-vector", else: "sort-vector-2"} {testid("edit-link-button")} class="blue-planning-300 w-5 h-5" />
            </button>
          </div>
        <% end %>
      </div>
    """
  end

  defp details_cell(assigns) do
    ~H"""
    <div class="sm:col-span-2 grid sm:flex gap-2 sm:gap-0">
      <.blurred_thumbnail class="h-32 rounded-lg" url={@booking_event.thumbnail_url} />
      <div class="flex flex-col items-start justify-center sm:ml-4">
        <%= case @booking_event.status do %>
        <% :archive -> %>
          <.badge color={:gray}>Archived</.badge>
        <% :disabled -> %>
          <.badge color={:gray}>Disabled</.badge>
        <% _ -> %>
          <p class="font-semibold"><%= @booking_event.date |> Calendar.strftime("%m/%d/%Y") %></p>
        <% end %>
        <div class="font-bold w-full">
          <a href={if @booking_event.status in [:disabled, :archive], do: "javascript:void(0)", else: Routes.calendar_booking_events_path(@socket, :edit, @booking_event.id)} style="text-decoration-thickness: 2px" class="block pt-2 underline underline-offset-1">
            <span class="w-full text-blue-planning-300 underline">
              <%= if String.length(@booking_event.name) < 30 do
                @booking_event.name
              else
                "#{@booking_event.name |> String.slice(0..29)} ..."
              end %>
            </span>
          </a>
        </div>
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
    <div class="flex flex-wrap gap-3 items-center justify-start md:w-auto w-full col-span-2">
      <.icon_button icon="eye" disabled={if @booking_event.status in [:archive, :disabled], do: 'disabled'} color="white" class="justify-center bg-blue-planning-300 hover:bg-blue-planning-300/75 grow flex-shrink-0 xl:w-auto sm:w-full" href={@booking_event.url} target="_blank" rel="noopener noreferrer">
        Preview
      </.icon_button>
      <.icon_button icon="anchor" disabled={if @booking_event.status in [:archive, :disabled], do: 'disabled'} color="blue-planning-300" class="justify-center text-blue-planning-300 grow flex-shrink-0 xl:w-auto sm:w-full" id={"copy-event-link-#{@booking_event.id}"} data-clipboard-text={@booking_event.url} phx-hook="Clipboard">
        <span>Copy link</span>
        <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
          Copied!
        </div>
      </.icon_button>
      <div class="flex items-center md:ml-auto w-full md:w-auto left-3 sm:left-8" data-offset-x="-21" data-placement="bottom-end" phx-hook="Select" id={"manage-event-#{@booking_event.id}-#{@booking_event.status}"}>
        <button {testid("actions")} title="Manage" class="btn-tertiary px-2 py-1 flex items-center gap-3 mr-2 text-blue-planning-300 w-full" id="Manage">
          Actions
          <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
          <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
        </button>
        <div class="z-10 flex hidden flex-col w-44 bg-white border rounded-lg shadow-lg popover-content">
          <%= case @booking_event.status do %>
          <% :archive -> %>
            <.button title="Unarchive" icon="plus"  click_event="unarchive-event" id={@booking_event.id} color="blue-planning" />
          <% status -> %>
            <.button title="Edit" hidden={if @booking_event.status == :disabled, do: 'hidden'} icon="pencil"  click_event="edit-event" id={@booking_event.id} color="blue-planning" />
            <.button title="Send update" icon="envelope"  click_event="send-email" id={@booking_event.id} color="blue-planning" />
            <.button title="Duplicate" icon="duplicate"  click_event="duplicate-event" id={@booking_event.id} color="blue-planning" />
            <%= case status do %>
            <% :active -> %>
              <.button title="Disable" icon="eye"  click_event="confirm-disable-event" id={@booking_event.id} color="red-sales" />
            <% :disabled-> %>
              <.button title="Enable" icon="plus"  click_event="enable-event" id={@booking_event.id} color="blue-planning" />
            <% end %>
            <.button title="Archive" icon="trash" click_event="confirm-archive-event" id={@booking_event.id} color="red-sales" />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "search",
        %{"search_phrase" => search_phrase},
        socket
      ) do
    search_phrase = String.trim(search_phrase)

    search_phrase =
      if String.length(search_phrase) > 0, do: String.downcase(search_phrase), else: nil

    socket
    |> assign(search_phrase: search_phrase)
    |> assign_booking_events()
    |> noreply()
  end

  @impl true
  def handle_event("clear-search", _, socket) do
    socket
    |> assign(:search_phrase, nil)
    |> assign_booking_events()
    |> noreply()
  end

  @impl true
  def handle_event("switch_sort", _, %{assigns: %{sort_direction: sort_direction}} = socket) do
    direction = if sort_direction == "asc", do: "desc", else: "asc"

    socket
    |> assign(:sort_direction, direction)
    |> assign_booking_events()
    |> noreply()
  end

  def handle_event("send-email", %{"event-id" => _id}, socket), do: socket |> noreply()

  # prevent search from submit
  def handle_event("submit", _, socket), do: socket |> noreply()

  @impl true
  def handle_event(
        "apply-filter-sort-by",
        %{"option" => sort_by},
        socket
      ) do
    socket
    |> assign(:sort_by, sort_by)
    |> assign(:sort_col, Enum.find(sort_options(), fn op -> op.id == sort_by end).column)
    |> assign_booking_events()
    |> noreply()
  end

  @impl true
  def handle_event(
        "apply-filter-status",
        %{"option" => status},
        socket
      ) do
    socket
    |> assign(:event_status, status)
    |> assign_booking_events()
    |> noreply()
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
  def handle_event("confirm-archive-event", %{"event-id" => id}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      title: "Are you sure?",
      subtitle: """
      Are you sure you want to archive this event?
      """,
      confirm_event: "archive_event_" <> id,
      confirm_label: "Yes, archive",
      close_label: "Cancel",
      icon: "warning-orange"
    })
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
  def handle_event(
        "unarchive-event",
        %{"event-id" => id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.enable_booking_event(id, current_user.organization_id) do
      {:ok, _event} ->
        socket
        |> assign_booking_events()
        |> put_flash(:success, "Event unarchive successfully")
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:success, "Error unarchiving event")
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
        |> assign_booking_events()
        |> put_flash(:success, "Event disabled successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error disabling event")
    end
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "archive_event_" <> id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.archive_booking_event(id, current_user.organization_id) do
      {:ok, _event} ->
        socket
        |> assign_booking_events()
        |> put_flash(:success, "Event archive successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error archiving event")
    end
    |> close_modal()
    |> noreply()
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

  defp assign_booking_events(
         %{
           assigns: %{
             current_user: current_user,
             sort_col: sort_by,
             sort_direction: sort_direction,
             search_phrase: search_phrase,
             event_status: event_status
           }
         } = socket
       ) do
    booking_events =
      BookingEvents.get_booking_events(current_user.organization_id,
        filters: %{
          sort_by: String.to_atom(sort_by),
          sort_direction: String.to_atom(sort_direction),
          search_phrase: search_phrase,
          status: event_status
        }
      )
      |> Enum.map(fn booking_event ->
        booking_event
        |> assign_sort_date(sort_direction, sort_by, event_status)
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
      |> filter_date(event_status)
      |> sort_by_date(sort_direction, sort_by)

    socket
    |> assign(booking_events: booking_events)
  end

  def sort_by_date(booking_events, sort_direction, "date") do
    sort_direction = String.to_atom(sort_direction)

    booking_events
    |> Enum.sort_by(& &1.date, {sort_direction, Date})
  end

  def sort_by_date(booking_events, _sort_direction, _sort_by), do: booking_events

  defp assign_sort_date(booking_event, sort_direction, sort_by, filter_status) do
    sorted_date =
      if sort_by == "date" || filter_status in ["future_events", "past_events"] do
        sort_direction =
          case filter_status do
            "future_events" -> :desc
            "past_events" -> :asc
            _ -> String.to_atom(sort_direction)
          end

        booking_event
        |> Map.get(:dates)
        |> Enum.map(& &1.date)
        |> Enum.sort_by(& &1, {sort_direction, Date})
        |> hd
      else
        booking_event.dates |> hd |> Map.get(:date)
      end

    booking_event
    |> Map.put(:date, sorted_date)
  end

  defp filter_date(booking_events, "future_events"),
    do: filter_booking_events(booking_events, :desc, :gt)

  defp filter_date(booking_events, "past_events"),
    do: filter_booking_events(booking_events, :asc, :lt)

  defp filter_date(booking_events, _filter_status), do: booking_events

  defp filter_booking_events(booking_events, sort_by, condition) do
    {:ok, datetime} = DateTime.now("Etc/UTC")

    booking_events
    |> Enum.filter(fn booking_event ->
      date =
        booking_event
        |> Map.get(:dates)
        |> Enum.map(& &1.date)
        |> Enum.sort_by(& &1, {sort_by, Date})
        |> hd

      Date.compare(date, datetime) == condition
    end)
  end

  defp sort_options do
    [
      %{title: "Event Date", id: "event_date", column: "date"},
      %{title: "Name", id: "name", column: "name"},
      %{title: "# of bookings", id: "#_of_bookings", column: "id"}
    ]
  end

  defp filter_options do
    [
      %{title: "All", id: "all"},
      %{title: "Future Events", id: "future_events"},
      %{title: "Past Events", id: "past_events"},
      %{title: "Disabled Events", id: "disabled_events"},
      %{title: "Archived Events", id: "archived_events"}
    ]
  end

  defp button(assigns) do
    assigns =
      assigns
      |> Map.put(:rest, Map.drop(assigns, [:color, :icon, :inner_block, :class, :disabled, :id]))
      |> Enum.into(%{class: "", hidden: "", disabled: false, inner_block: nil})

    ~H"""
      <button title={@title} type="button" phx-click={@click_event} phx-value-event-id={@id} class={"flex items-center px-3 py-2 rounded-lg hover:bg-#{@color}-100 hover:font-bold #{@hidden}"} disabled={@disabled} {@rest}>
        <.icon name={@icon} class={"inline-block w-4 h-4 mr-3 fill-current text-#{@color}-300"} />
        <%= @title %>
      </button>
    """
  end

  def capitalize_per_word(string) do
    String.split(string)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
