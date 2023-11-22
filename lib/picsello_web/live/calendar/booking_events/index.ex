defmodule PicselloWeb.Live.Calendar.BookingEvents.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  import PicselloWeb.Live.Shared, only: [save_filters: 3]
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import PicselloWeb.ClientBookingEventLive.Shared, only: [blurred_thumbnail: 1]

  alias PicselloWeb.Calendar.BookingEvents.Shared, as: BEShared
  alias Picsello.BookingEvents, as: BE
  alias PicselloWeb.Live.Calendar.EditMarketingEvent
  alias Picsello.{Utils, Payments, BookingEvents, PreferredFilter}

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: current_user}} = socket) do
    socket
    |> assign(:page_title, "Booking Events")
    |> assign(stripe_status: Payments.status(current_user))
    |> assign_defaults()
    |> assign_booking_events()
    |> assign_preferred_filters()
    |> ok()
  end

  @impl true
  def handle_params(_, _, socket) do
    socket |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pt-6 px-6 py-2 center-container mt-12 sm:mt-0">
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
        <div class="fixed top-12 left-0 right-0 z-10 flex flex-shrink-0 w-full sm:p-0 p-6 mt-1 sm:mt-0 sm:bottom-auto sm:ml-auto sm:static sm:items-start sm:w-auto">
          <a title="add booking event" class="w-full md:w-auto btn-primary text-center cursor-pointer" phx-click="new-event">
            Add booking event
          </a>
        </div>
      </div>
      <%= unless [:charges_enabled, :loading] |> Enum.member?(@stripe_status) do %>
        <div class="flex flex-col items-center px-4 py-2 mt-8 text-center rounded-lg md:flex-row bg-red-sales-300/10 sm:text-left">
          <.icon name="warning-orange-dark" class="inline-block w-4 h-4 mr-2"/>
            It looks like you haven’t setup Stripe yet. You won’t be able to enable your events until that is setup.
          <div class="flex-shrink-0 my-1 mt-4 md:ml-auto sm:max-w-xs sm:mt-0">
            <%= live_component PicselloWeb.StripeOnboardingComponent, id: :stripe_onboarding_banner,
                  error_class: "text-center",
                  current_user: @current_user,
                  class: "btn-primary py-1 px-3 text-sm intro-stripe mx-auto block",
                  return_url: PicselloWeb.Helpers.booking_events_url(),
                  stripe_status: @stripe_status %>
          </div>
        </div>
      <% end %>
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
              <a title="add booking event" class="w-full cursor-pointer md:w-auto btn-primary text-center" phx-click="new-event">
                Add booking event
              </a>
            </.empty_state_base>
          </div>
        <% end %>
    </div>
    <% else %>
      <div class="p-6 center-container">
        <div class="hidden sm:grid sm:grid-cols-5 gap-2 border-b-8 border-blue-planning-300 font-semibold text-lg pb-6">
          <div class="sm:col-span-2">Event Details</div>
          <div>Bookings so far</div>
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
  def handle_event(
        "switch-sort",
        _,
        %{
          assigns: %{
            sort_direction: sort_direction,
            current_user: %{organization_id: organization_id}
          }
        } = socket
      ) do
    direction = if sort_direction == "asc", do: "desc", else: "asc"
    save_filters(organization_id, "booking_events", %{sort_direction: direction})

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
        %{assigns: %{current_user: %{organization_id: organization_id}}} = socket
      ) do
    save_filters(organization_id, "booking_events", %{sort_by: sort_by})

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
        %{assigns: %{current_user: %{organization_id: organization_id}}} = socket
      ) do
    save_filters(organization_id, "booking_events", %{event_status: status})

    socket
    |> assign(:event_status, status)
    |> assign_booking_events()
    |> noreply()
  end

  @impl true
  def handle_event("edit-event", %{"event-id" => id}, socket) do
    socket
    |> redirect(to: Routes.calendar_booking_events_show_path(socket, :edit, id))
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-marketing-event",
        %{"event-id" => id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> EditMarketingEvent.open(%{
      event_id: id,
      current_user: current_user
    })
  end

  @impl true
  def handle_event(
        "unarchive-event",
        %{"event-id" => id},
        %{assigns: %{current_user: current_user, stripe_status: stripe_status}} = socket
      ) do
    with true <- [:charges_enabled, :loading] |> Enum.member?(stripe_status),
         {:ok, _event} <- BookingEvents.enable_booking_event(id, current_user.organization_id) do
      socket
      |> assign_booking_events()
      |> put_flash(:success, "Event enabled successfully")
    else
      false ->
        socket
        |> put_flash(:error, "Please setup stripe first")

      {:error, _} ->
        socket
        |> put_flash(:error, "Error enabling event")
    end
    |> noreply()
  end

  @impl true
  def handle_info({:stripe_status, status}, socket) do
    socket
    |> assign(stripe_status: status)
    |> noreply()
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
        |> put_flash(:error, "Error disabling event")
    end
    |> close_modal()
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: BEShared

  @impl true
  def handle_info({:update, %{booking_event: _booking_event}}, socket) do
    socket
    |> assign_booking_events()
    |> put_flash(:success, "Booking event saved successfully")
    |> noreply()
  end

  @impl true
  defdelegate handle_info(message, socket), to: BEShared

  defp bookings_cell(assigns) do
    ~H"""
    <div class="flex flex-col justify-center">
      <p><%= if BEShared.incomplete_status?(@booking_event), do: "-", else: ngettext("%{count} booking", "%{count} bookings", @booking_event.booking_count) <> " so far" %></p>
    </div>
    """
  end

  defp actions_cell(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-3 items-center lg:ml-auto justify-start md:w-auto w-full col-span-2">
      <%= if BEShared.incomplete_status?(@booking_event) do %>
        <.icon_button phx-click="edit-event" phx-value-event-id={@booking_event.id} icon="pencil" color="white" class="justify-center bg-blue-planning-300 hover:bg-blue-planning-300/75 grow sm:grow-0 flex-shrink-0 xl:w-auto sm:w-full p-1 px-3" rel="noopener noreferrer">
          Edit
        </.icon_button>
      <% else %>
        <.icon_button icon="eye" color="white" class="justify-center bg-blue-planning-300 hover:bg-blue-planning-300/75 grow sm:grow-0 flex-shrink-0 xl:w-auto sm:w-full" href={@booking_event.url} target="_blank" rel="noopener noreferrer">
          Preview
        </.icon_button>
        <.icon_button icon="anchor" color="blue-planning-300" class="justify-center text-blue-planning-300 grow md:grow-0 flex-shrink-0 xl:w-auto sm:w-full p-1 px-2" id={"copy-event-link-#{@booking_event.id}"} data-clipboard-text={@booking_event.url} phx-hook="Clipboard">
          <span>Copy link</span>
          <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
            Copied!
          </div>
        </.icon_button>
      <% end %>
      <div class="flex items-center w-full xl:w-auto grow sm:grow-0" data-offset-x="-21" data-placement="bottom-end" phx-hook="Select" id={"manage-event-#{@booking_event.id}-#{@booking_event.status}"}>
        <button {testid("actions")} title="Manage" class="btn-tertiary px-2 py-1 flex items-center gap-3 mr-2 text-blue-planning-300 w-full">
          Actions
          <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
          <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
        </button>
        <div class="z-10 flex hidden flex-col w-44 bg-white border rounded-lg shadow-lg popover-content">
          <%= case @booking_event.status do %>
            <% :archive -> %>
              <.button title="Unarchive" icon="plus"  click_event="unarchive-event" id={@booking_event.id} color="blue-planning" />
            <% status -> %>
              <.button title="Edit" hidden={BEShared.disabled?(@booking_event, [:disabled]) && 'hidden'} icon="pencil"  click_event="edit-event" id={@booking_event.id} color="blue-planning" />
              <.button title="Send update" icon="envelope"  click_event="send-email" id={@booking_event.id} color="blue-planning" />
              <.button title="Duplicate" icon="duplicate"  click_event="duplicate-event" id={@booking_event.id} color="blue-planning" />
              <%= cond do %>
                <% status == :active && !BEShared.incomplete_status?(@booking_event) -> %>
                  <.button title="Disable" icon="eye"  click_event="confirm-disable-event" id={@booking_event.id} color="red-sales" />
                  <.button title="Archive" icon="trash"  click_event="confirm-archive-event" id={@booking_event.id} color="red-sales" />
                <% :disabled-> %>
                  <.button title="Enable" icon="plus"  click_event="enable-event" id={@booking_event.id} color="blue-planning" />
              <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp select_dropdown(assigns) do
    ~H"""
    <h1 class="font-extrabold text-sm flex flex-col"><%= @title %></h1>
      <div class="flex">
        <div id="select" class={classes("relative w-40 border-grey border rounded-l-lg p-2 cursor-pointer", %{"rounded-lg" => @title == "Filter"})} data-offset-y="5" phx-hook="Select">
          <div class="flex flex-row items-center border-gray-700">
            <%= Utils.capitalize_all_words(String.replace(@selected_option, "_", " ")) %>
            <.icon name="down" class="w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 open-icon" />
            <.icon name="up" class="hidden w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 close-icon" />
          </div>
          <ul class={classes("absolute z-30 hidden mt-2 bg-white toggle rounded-md popover-content border border-base-200",%{"w-41" => @id == "status", "w-40" => @id=="sort-by"})}>
            <%= for option <- @options_list do %>
              <li id={option.id} target-class="toggle-it" parent-class="toggle" toggle-type="selected-active" phx-hook="ToggleSiblings"
              class="flex items-center py-1.5 hover:bg-blue-planning-100 hover:rounded-md">

                <button class="album-select w-40" phx-click={"apply-filter-#{@id}"} phx-value-option={option.id}><%= option.title %></button>
                <%= if option.id == @selected_option do %>
                  <.icon name="tick" class="w-6 h-5 mr-1 toggle-it text-green" />
                <% end %>
              </li>
            <% end %>
          </ul>
        </div>
        <%= if @title == "Sort" do%>
          <div class="items-center flex border rounded-r-lg border-grey p-2">
            <button phx-click="switch-sort">
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
        <%= cond do %>
          <% BEShared.incomplete_status?(@booking_event) -> %>
            <.badge color={:gray}>Incomplete-Disabled</.badge>
          <% @booking_event.status == :archive and not BEShared.incomplete_status?(@booking_event) -> %>
            <.badge color={:gray}>Archived</.badge>
          <% @booking_event.status == :disabled -> %>
            <.badge color={:gray}>Disabled</.badge>
          <% true -> %>
            <p class="font-semibold"><%= if Map.has_key?(@booking_event, :date) && !is_nil(@booking_event.date), do: @booking_event.date |> Calendar.strftime("%m/%d/%Y"), else: "Date not set" %></p>
        <% end %>
        <div class="font-bold w-full">
          <a href={if BEShared.disabled?(@booking_event, [:disabled, :archive]), do: "javascript:void(0)", else: Routes.calendar_booking_events_show_path(@socket, :edit, @booking_event.id)} style="text-decoration-thickness: 2px" class="block pt-2 underline underline-offset-1">
            <span class="w-full text-blue-planning-300 underline">
              <%= if String.length(@booking_event.name) < 30 do
                @booking_event.name
              else
                "#{String.slice(@booking_event.name, 0..29)} ..."
              end %>
            </span>
          </a>
        </div>
        <div class="text-gray-400">
          <p class={classes(%{"text-red-sales-300 font-bold" => is_nil(@booking_event.package_name)})}><%= if is_nil(@booking_event.package_name), do: "No package selected", else: @booking_event.package_name  %></p>
          <p>
         <%= if @booking_event.duration_minutes do %>
            <%= @booking_event.duration_minutes %> minutes
          <% else %>
            -
          <% end %>
      </p>
        </div>
      </div>
    </div>
    """
  end

  defp assign_defaults(socket) do
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

  defp assign_preferred_filters(
    %{assigns: %{current_user: %{organization_id: organization_id}}} = socket
  ) do
    case PreferredFilter.load_preferred_filters(organization_id, "booking_events") do
    %{
      filters: %{
        event_status: event_status,
        sort_by: sort_by,
        sort_direction: sort_direction
      }
    } ->
      socket
      |> assign_default_filters(event_status, sort_by, sort_direction)
      |> assign_sort_col(sort_by, "name")

    _ ->
      socket
      |> assign_default_filters("all", "name", "asc")
      |> assign(:sort_col, "name")
    end
  end

  defp assign_default_filters(socket, event_status, sort_by, sort_direction),
  do:
    socket
    |> assign(:event_status, event_status || "all")
    |> assign(:sort_by, sort_by || "name")
    |> assign(:sort_direction, sort_direction || "asc")

  defp assign_sort_col(socket, nil, default_sort_col),
  do:
    socket
    |> assign(:sort_col, default_sort_col)

  defp assign_sort_col(socket, sort_by, _default_sort_col),
  do:
    socket
    |> assign(:sort_col, Enum.find(sort_options(), &(&1.id == sort_by)).column)


  def assign_booking_events(
        %{
          assigns: %{
            current_user: %{organization: organization},
            sort_col: sort_by,
            sort_direction: sort_direction,
            search_phrase: search_phrase,
            event_status: event_status
          }
        } = socket
      ) do
    booking_events =
      BE.get_booking_events(organization.id,
        filters: %{
          sort_by: String.to_atom(sort_by),
          sort_direction: String.to_atom(sort_direction),
          search_phrase: search_phrase,
          status: event_status
        }
      )

    booking_events_with_nil_dates =
      booking_events
      |> filter_booking_events_with_dates()
      |> Enum.map(&BEShared.put_url_booking_event(&1, organization, socket))

    booking_events_with_dates = booking_events |> filter_nil_dates_booking_events()

    booking_events =
      booking_events_with_dates
      |> Enum.map(fn booking_event ->
        booking_event
        |> assign_sort_date(sort_direction, sort_by, event_status)
        |> BEShared.put_url_booking_event(organization, socket)
      end)
      |> filter_date(event_status)
      |> sort_by_date(sort_direction, sort_by)
      |> Kernel.++(booking_events_with_nil_dates)

    socket
    |> assign(booking_events: booking_events)
  end

  def sort_by_date(booking_events, sort_direction, "date") do
    sort_direction = String.to_atom(sort_direction)

    booking_events
    |> Enum.sort_by(& &1.date, {sort_direction, Date})
  end

  def sort_by_date(booking_events, _sort_direction, _sort_by), do: booking_events

  # this function removes all the booking events with 'date' as date in 'dates'
  # end result would be all the booking events that have nil date in dates field
  defp filter_booking_events_with_dates(booking_events) do
    booking_events
    |> Enum.reduce_while([], fn booking_event, acc ->
      if Enum.all?(booking_event.dates, fn b ->
           is_nil(b["date"])
         end) do
        {:cont, acc ++ [booking_event]}
      else
        {:cont, acc}
      end
    end)
  end

  # this function removes all the booking events with 'date' as nil in 'dates'
  # end result would be booking events with date in their dates field
  defp filter_nil_dates_booking_events(booking_events) do
    booking_events
    |> Enum.reduce_while([], fn booking_event, acc ->
      if Enum.all?(booking_event.dates, fn b ->
           !is_nil(b["date"])
         end) do
        {:cont, acc ++ [booking_event]}
      else
        do_filter_nil_dates(booking_event, acc)
      end
    end)
  end

  defp do_filter_nil_dates(booking_event, acc) do
    if Enum.any?(booking_event.dates, fn d ->
         !is_nil(BEShared.get_date(d))
       end) do
      filtered_dates =
        Enum.reduce_while(booking_event.dates, [], fn d, acc_dates ->
          if is_nil(BEShared.get_date(d)) do
            {:cont, acc_dates}
          else
            {:cont, acc_dates ++ [d]}
          end
        end)

      booking_event = Map.replace(booking_event, :dates, filtered_dates)
      {:cont, acc ++ [booking_event]}
    else
      {:cont, acc}
    end
  end

  defp assign_sort_date(%{dates: []} = booking_event, _sort_direction, _sort_by, _filter_status),
    do: booking_event |> Map.put(:date, nil)

  defp assign_sort_date(booking_event, sort_direction, sort_by, filter_status) do
    sorted_date =
      cond do
        Enum.empty?(booking_event.dates) ->
          booking_event

        sort_by == "date" || filter_status in ["future_events", "past_events"] ->
          sort_booking_event(booking_event, filter_status, sort_direction)

        true ->
          booking_event
          |> Map.get(:dates)
          |> hd
          |> Map.get("date")
          |> case do
            nil -> nil
            date -> date |> Date.from_iso8601!()
          end
      end

    booking_event
    |> Map.put(:date, sorted_date)
  end

  defp sort_booking_event(booking_event, filter_status, sort_direction) do
    sort_direction =
      case filter_status do
        "future_events" -> :desc
        "past_events" -> :asc
        _ -> String.to_atom(sort_direction)
      end

    booking_event
    |> Map.get(:dates)
    |> Enum.map(&BEShared.get_date(&1))
    |> Enum.map(&BEShared.convert_date_string_to_date(&1))
    |> Enum.reject(&is_nil(&1))
    |> Enum.sort_by(& &1, {sort_direction, Date})
    |> hd()
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
        |> Enum.map(&BEShared.get_date(&1))
        |> Enum.map(&BEShared.convert_date_string_to_date(&1))
        |> Enum.reject(&is_nil(&1))
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
end
