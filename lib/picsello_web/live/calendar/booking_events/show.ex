defmodule PicselloWeb.Live.Calendar.BookingEvents.Show do
  @moduledoc false
  use PicselloWeb, :live_view

  import PicselloWeb.Live.Shared, only: [update_package_questionnaire: 1]
  import PicselloWeb.Shared.EditNameComponent, only: [edit_name_input: 1]
  import PicselloWeb.GalleryLive.Shared, only: [add_message_and_notify: 3]

  import PicselloWeb.ClientBookingEventLive.Shared,
    only: [
      blurred_thumbnail: 1,
      date_display: 1,
      address_display: 1
    ]

  import PicselloWeb.BookingProposalLive.Shared, only: [package_description_length_long?: 1]

  alias Picsello.{
    Repo,
    Package,
    BookingEvent,
    BookingEvents,
    BookingProposal,
    BookingEventDate,
    BookingEventDates
  }

  alias PicselloWeb.Live.Calendar.{BookingEventModal, EditMarketingEvent}
  alias PicselloWeb.BookingProposalLive.{QuestionnaireComponent, ContractComponent}
  alias PicselloWeb.Calendar.BookingEvents.Shared, as: BEShared

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:collapsed_sections, [])
    |> ok()
  end

  @impl true
  def handle_params(
        %{"id" => event_id},
        _session,
        %{assigns: %{current_user: %{organization_id: organization_id}}} = socket
      ) do
    socket
    |> assign(:id, to_integer(event_id))
    |> assign(:edit_name, false)
    |> assign(:booking_event, BookingEvents.get_booking_event!(organization_id, event_id))
    |> BEShared.assign_events()
    |> assign_changeset(%{})
    |> then(fn %{assigns: %{booking_event: booking_event}} = socket ->
      socket
      |> assign(
        :booking_slot_tab_active,
        if(booking_event.is_repeating, do: "calendar", else: "list")
      )
    end)
    |> assign(:booking_slot_tabs, booking_slot_tabs())
    |> noreply()
  end

  @impl true
  def handle_params(_, _, socket) do
    socket |> noreply()
  end

  @impl true
  def handle_event(
        "calendar-date-changed",
        %{"date" => calendar_date},
        %{assigns: %{booking_event: booking_event}} = socket
      ) do
    {:ok, calendar_date} = Date.from_iso8601(calendar_date)

    calendar_event = Enum.find(booking_event.dates, &(&1.date == calendar_date))

    socket
    |> assign(:calendar_date_event, calendar_event)
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-date",
        _,
        %{
          assigns: %{
            booking_event: booking_event,
            current_user: %{organization_id: organization_id}
          }
        } = socket
      ) do
    booking_date = %BookingEventDate{
      booking_event_id: booking_event.id,
      organization_id: organization_id
    }

    socket
    |> open_wizard(%{
      booking_date: booking_date,
      title: "Add Date",
      is_repeating: booking_event.is_repeating
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-date",
        %{"id" => date_id},
        %{
          assigns: %{
            booking_event: booking_event,
            current_user: %{organization_id: organization_id}
          }
        } = socket
      ) do
    booking_date = BEShared.get_booking_date(booking_event, to_integer(date_id))

    edit_booking_date =
      booking_date
      |> Map.put(:organization_id, organization_id)
      |> Map.put(
        :slots,
        booking_date
        |> BEShared.update_slots_for_edit()
      )

    socket
    |> open_wizard(%{booking_date: edit_booking_date, title: "Edit Date"})
    |> noreply()
  end

  @impl true
  def handle_event(
        "duplicate-date",
        %{"id" => date_id},
        %{assigns: %{current_user: %{organization_id: org_id}, booking_event: booking_event}} =
          socket
      ) do
    to_duplicate_date = %BookingEventDate{
      booking_event_id: booking_event.id,
      organization_id: org_id
    }

    duplicate_date =
      booking_event
      |> BEShared.get_booking_date(to_integer(date_id))
      |> Map.from_struct()

    to_duplicate_date =
      to_duplicate_date
      |> Map.put(:session_length, duplicate_date.session_length)
      |> Map.put(:session_gap, duplicate_date.session_gap)
      |> Map.put(
        :slots,
        duplicate_date.slots
        |> BookingEventDates.transform_slots()
      )
      |> Map.put(:time_blocks, duplicate_date.time_blocks)

    socket
    |> open_wizard(%{booking_date: to_duplicate_date, title: "Duplicate Date"})
    |> noreply()
  end

  @impl true
  def handle_event("confirm-delete-date", %{"id" => date_id}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Get me out of here",
      confirm_event: "delete-date-" <> date_id,
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Are you sure?",
      subtitle: "Are you sure you want to delete this date from the event?"
    })
    |> noreply()
  end

  @impl true
  def handle_event("change-booking-slot-tab", %{"tab" => tab}, socket) do
    socket
    |> assign(:booking_slot_tab_active, tab)
    |> noreply()
  end

  @impl true
  def handle_event("add-package", _, socket) do
    socket
    |> open_modal(
      PicselloWeb.PackageLive.WizardComponent,
      Map.take(socket.assigns, [:current_user, :currency, :booking_event])
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-questionnaire",
        %{},
        socket
      ) do
    socket
    |> QuestionnaireComponent.open_modal_from_booking_events()
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-questionnaire",
        _,
        socket
      ) do
    socket
    |> update_package_questionnaire()
  end

  @impl true
  def handle_event(
        "open-contract",
        _,
        socket
      ) do
    socket
    |> ContractComponent.open_modal_from_booking_events()
    |> noreply()
  end

  @impl true
  def handle_event(
        "link-copied",
        _,
        socket
      ) do
    socket
    |> put_flash(:success, "Booking link copied!")
    |> noreply()
  end

  @impl true
  def handle_event("add-contract", %{}, socket) do
    socket
    |> PicselloWeb.ContractFormComponent.open(
      Map.take(socket.assigns, [:package, :booking_event, :current_user])
    )
    |> noreply()
  end

  @impl true
  def handle_event("replace-package", _, %{assigns: %{booking_event: booking_event}} = socket) do
    booking_event = Map.put(booking_event, :package_template, nil)

    socket
    |> open_modal(
      PicselloWeb.PackageLive.WizardComponent,
      Map.take(socket.assigns, [:current_user, :currency])
      |> Map.put(:booking_event, booking_event)
    )
    |> noreply()
  end

  @impl true
  def handle_event("change-booking-event-tab", %{"tab" => tab}, socket) do
    socket
    |> assign(:booking_event_tab_active, tab)
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle-section",
        %{"section_id" => section_id},
        %{assigns: %{collapsed_sections: collapsed_sections}} = socket
      ) do
    section_id = to_integer(section_id)

    collapsed_sections =
      if Enum.member?(collapsed_sections, section_id) do
        Enum.filter(collapsed_sections, &(&1 != section_id))
      else
        collapsed_sections ++ [section_id]
      end

    socket
    |> assign(:collapsed_sections, collapsed_sections)
    |> noreply()
  end

  @impl true
  def handle_event("toggle_booking_slot_tab", %{"id" => booking_slot_tab}, socket) do
    socket
    |> assign(:booking_slot_tab, booking_slot_tab)
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
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: BEShared

  @impl true
  def handle_info({:wizard_closed, _modal}, %{assigns: assigns} = socket) do
    assigns
    |> Map.get(:flash, %{})
    |> Enum.reduce(socket, fn {kind, msg}, socket -> put_flash(socket, kind, msg) end)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:update, %{booking_event_date: _booking_date}},
        socket
      ) do
    socket
    |> put_flash(:success, "Booking event date saved successfully")
    |> BEShared.assign_events()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete-date-" <> id},
        socket
      ) do
    case BookingEventDates.delete_booking_event_date(to_integer(id)) do
      {:ok, _} ->
        socket
        |> BEShared.assign_events()
        |> put_flash(:success, "Event date deleted successfully")

      {:error, _} ->
        socket
        |> put_flash(:error, "Error deleting event date")
    end
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:update, %{package: _package}},
        socket
      ) do
    socket
    |> BEShared.assign_events()
    |> put_flash(:success, "Package details saved sucessfully.")
    |> noreply()
  end

  @impl true
  def handle_info(
        {:update, %{questionnaire: _questionnaire}},
        %{assigns: %{package: package}} = socket
      ) do
    package = package |> Repo.preload(:questionnaire_template, force: true)

    socket
    |> assign(:package, package)
    |> put_flash(:success, "Questionnaire updated")
    |> noreply()
  end

  @impl true
  def handle_info(
        {:update, %{booking_event: booking_event}},
        socket
      ) do
    socket
    |> assign(:booking_event, booking_event)
    |> put_flash(:success, "Marketing details updated")
    |> noreply()
  end

  @impl true
  def handle_info({:contract_saved, contract}, %{assigns: %{package: package}} = socket) do
    socket
    |> assign(package: %{package | contract: contract})
    |> put_flash(:success, "Contract updated successfully")
    |> close_modal()
    |> noreply()
  end

  def handle_info(
        {:validate, %{"booking_event" => params}},
        socket
      ) do
    socket
    |> assign(:edit_name, true)
    |> assign_changeset(params)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:save, %{"booking_event" => %{"name" => _}}},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    case BookingEvents.upsert_booking_event(changeset) do
      {:ok, booking_event} ->
        socket
        |> assign(:edit_name, false)
        |> assign(:booking_event, booking_event)
        |> put_flash(:success, "Booking Event updated successfully")

      {:error, changeset} ->
        socket |> assign(changeset: changeset)
    end
    |> noreply()
  end

  def handle_info({:message_composed, message_changeset, recipients}, socket) do
    add_message_and_notify(socket, message_changeset, recipients)
  end

  @impl true
  defdelegate handle_info(message, socket), to: BEShared

  defp booking_slot_tabs_nav(assigns) do
    ~H"""
    <ul class="flex overflow-auto gap-6 mb-6 py-6 md:py-0">
      <%= for {true, %{name: name, concise_name: concise_name, redirect_route: redirect_route}} <- @booking_slot_tabs do %>
        <li class={classes("text-blue-planning-300 font-bold text-lg border-b-4 transition-all shrink-0", %{"opacity-100 border-b-blue-planning-300" => @booking_slot_tab_active === concise_name, "opacity-40 border-b-transparent hover:opacity-100" => @booking_slot_tab_active !== concise_name})}>
          <button type="button" phx-click="change-booking-slot-tab" phx-value-tab={concise_name} phx-value-to={redirect_route}><%= name %></button>
        </li>
      <% end %>
    </ul>
    """
  end

  # Funtion Description: [Funtionality should be modified according to backend implementation] By default, status is 'nil' here. 'nil' status means 'Enabled'. If we pass status in assigns, it is recieved as 'disabled'. Similarly, by default, uses are '0'. We are to pass uses in assigns.
  defp add_coupon(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        status: nil,
        uses: 0,
        text_color: "text-black",
        btn_class: "border border-base-250/20 bg-base-200 hover:border-base-250 h-8 w-8"
      })

    ~H"""
      <div class="flex mt-2">
        <div>
          <div class={classes("uppercase text-lg font-bold", %{"text-base-250" => @status})}>BEESKNEES</div>
          <%= if !@status do %>
            <div class={classes("", %{"text-blue-planning-300 underline" => @uses > 0})}><%= @uses %> uses</div>
          <% else %>
            <%= if @uses > 0 do %>
              <div class="text-base-250 capitalize"><span class="text-blue-planning-300 underline opacity-60"><%= @uses %> uses</span>-Disabled</div>
            <% else %>
              <div class="text-base-250 capitalize">Disabled</div>
            <% end %>
          <% end %>
        </div>
        <div class="ml-auto flex items-center">
          <div class="flex gap-1.5">
            <%= if @status do %>
              <.icon_button icon="eye" color="blue-planning-300" text_color={@text_color} class={@btn_class}/>
            <% else %>
              <.icon_button icon="closed-eye" color="red-sales-300" text_color={@text_color} class={@btn_class}/>
            <% end %>
            <.icon_button icon="trash" color="red-sales-300" text_color={@text_color} class={@btn_class}/>
          </div>
        </div>
      </div>
    """
  end

  defp booking_slot_tabs_content(assigns) do
    ~H"""
    <div>
      <%= case @booking_slot_tab_active do %>
      <% "list" -> %>
        <%= if @booking_event_dates && @booking_event_dates != [] do %>
          <%= for booking_event_date <- @booking_event_dates do %>
            <div class={classes("mt-10 p-3 border rounded-lg border-base-200", %{"border-red-sales-300" => is_nil(booking_event_date.date)})}>
              <div class="flex mb-1">
                <p class="text-2xl font-bold"> <%= if booking_event_date.date, do: date_formatter(booking_event_date.date), else: "Add date" %> </p>
                <button class="flex text-blue-planning-300 ml-auto items-center justify-center whitespace-nowrap hover:opacity-75" phx-click="toggle-section" phx-value-section_id={booking_event_date.id}>
                  View details
                  <.icon name={if Enum.member?(@collapsed_sections, booking_event_date.id), do: "up", else: "down"} class="mt-1.5 md:mt-1 w-4 h-4 ml-2 stroke-current stroke-3 text-blue-planning-300"/>
                </button>
              </div>
              <p class="text-base-250 text-md"> <%= if !is_nil(booking_event_date.address), do: booking_event_date.address %> </p>
              <div class="flex">
                <p class="text-blue-planning-300 mr-4"><b><%= BEShared.count_booked_slots(booking_event_date.slots) %></b> bookings</p>
                <p class="text-blue-planning-300 mr-4"><b><%= BEShared.count_available_slots(booking_event_date.slots) %></b> available</p>
                <p class="text-blue-planning-300"><b><%= BEShared.count_hidden_slots(booking_event_date.slots) %></b> hidden</p>
              </div>
              <hr class="block md:hidden my-2">
              <%= if Enum.member?(@collapsed_sections, booking_event_date.id) do %>
                <div class="hidden md:grid grid-cols-7 border-b-4 border-blue-planning-300 font-bold text-lg my-4">
                <%= for title <- ["Time", "Status", "Client"] do %>
                  <div class="col-span-2"><%= title %></div>
                <% end %>
                </div>
                <%= Enum.with_index(booking_event_date.slots, fn slot, slot_index -> %>
                  <.slots_description current_user={@current_user} client={slot.client} booking_event_date={booking_event_date} booking_event={@booking_event} booking_slot_tab_active={@booking_slot_tab_active} slot_index={slot_index} slot={slot} button_actions={slot_actions(slot.status)} />
                <% end) %>
                <div class="flex justify-end gap-2">
                  <%= for %{action: action, icon: icon, disabled: disabled?} <- date_actions(@booking_slot_tab_active, @booking_event, booking_event_date) do %>
                    <.icon_button icon={icon} phx-click={action} phx-value-id={booking_event_date.id} disabled={disabled?} class="px-2 py-2" text_color={"text-black"} color={if icon == "trash", do: "red-sales-300", else: "blue-planning-300"}/>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <div class="p-3 border border-base-200 rounded-lg">
            <div class="font-bold text-base-250 text-xl flex items-center justify-center p-3 opacity-50"> <div> Pick a package and add a date </div> </div>
          </div>
        <% end %>

      <% "calendar" -> %>
        <div class="mt-10 flex flex-col xl:flex-row gap-8">
          <div class="flex xl:w-1/2 flex-col">
            <div phx-hook="BookingEventCalendar" phx-update="replace" id="booking_event_calendar" data-time-zone={@current_user.time_zone} data-feed-path={Routes.calendar_feed_path(@socket, :show, @booking_event.id)}/>
          </div>
          <div class="xl:h-[600px] flex flex-col flex-grow">
            <%= if @calendar_date_event do %>
              <div class="flex">
                <div class="flex text-2xl font-bold"><%= date_formatter(@calendar_date_event.date) %></div>
                <div class="flex justify-end ml-auto">
                  <%= for %{action: action, icon: icon, disabled: disabled?} <- date_actions(@booking_slot_tab_active, @booking_event, @calendar_date_event) do %>
                    <.icon_button icon={icon} phx-click={action} phx-value-id={@calendar_date_event.id} disabled={disabled?} class="px-2 py-2" text_color={"text-black"} color={if icon == "trash", do: "red-sales-300", else: "blue-planning-300"}/>
                  <% end %>
                </div>
              </div>
              <div class="flex mb-2">
                <p class="text-blue-planning-300 mr-4"><b><%= BEShared.count_booked_slots(@calendar_date_event.slots) %></b> bookings</p>
                <p class="text-blue-planning-300 mr-4"><b><%= BEShared.count_available_slots(@calendar_date_event.slots) %></b> available</p>
                <p class="text-blue-planning-300"><b><%= BEShared.count_hidden_slots(@calendar_date_event.slots) %></b> hidden</p>
              </div>
              <div class="xl:overflow-y-scroll flex flex-col gap-1.5">
              <%= Enum.with_index(@calendar_date_event.slots, fn slot, slot_index -> %>
                <.slots_description client={slot.client} slot_index={slot_index} booking_event_date={@calendar_date_event} booking_event={@booking_event} booking_slot_tab_active={@booking_slot_tab_active} slot={slot} button_actions={slot_actions(slot.status)} />
              <% end) %>
              </div>
            <% else %>
              <div class="p-3 border border-base-200 rounded-lg">
                <div class="font-bold text-base-250 text-xl flex items-center justify-center p-3 opacity-50"> <div> Pick a package and add a date </div> </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp slots_description(assigns) do
    ~H"""
      <%= case @booking_slot_tab_active do %>
        <% "list" -> %>
          <div class="grid grid-cols-3 md:grid-cols-7 items-start md:items-center my-2">
            <div class="col-span-7 grid grid-cols-2 md:grid-cols-6">
              <div class={classes("col-span-2", %{"text-base-250" => @slot.status == :hidden})}>
                <%= if @slot.status in [:booked, :reserved] do %>
                  <div class="flex gap-2 items-center">
                    <.icon name="clock-2" class="block md:hidden w-3 h-3 stroke-current text-blue-planning-300 mt-1" />
                    <button phx-click="open-job" phx-value-slot-job-id={@slot.job_id} class="text-blue-planning-300 underline"><%= slot_time_formatter(@slot) %></button>
                  </div>
                <% else %>
                  <div class="flex gap-2 items-center">
                    <.icon name="clock-2" class="block md:hidden w-3 h-3 stroke-current text-blue-planning-300 mt-1" />
                    <div><%= slot_time_formatter(@slot) %></div>
                  </div>
                <% end %>
              </div>
              <div class={classes("col-span-2", %{"text-base-250" => @slot.status != :open})}>
                <div class="flex gap-2 items-center lg:justify-start md:justify-center">
                  <.icon name={@slot.status != :open && "booked-slot" || "open-slot"} class="block md:hidden w-3 h-3 fill-blue-planning-300 mt-1.5" />
                  <div><%= String.capitalize(to_string(@slot.status)) %></div>
                </div>
              </div>
              <div class="col-span-2">
                <%= if @client && @slot.status in [:booked, :reserved] do %>
                  <div class="flex gap-2 items-center">
                    <.icon name="client-icon" class="block md:hidden w-3 h-3 text-blue-planning-300 mt-1.5" />
                    <div class="text-blue-planning-300 underline"><%= String.capitalize(@client.name) %></div>
                  </div>
                <% else %>
                  <div class="flex gap-2 items-center">
                    <.icon name="client-icon" class="block md:hidden w-3 h-3 text-blue-planning-300" />
                  </div>
                <% end %>
              </div>
              <div class="justify-start">
                <.actions id={@booking_event_date.id} booking_event_date_id={@booking_event_date.id} disabled?={disable_slot_actions?(@booking_event_date, @booking_event.status)} booking_event={@booking_event} button_actions={@button_actions} slot_index={@slot_index} slot_client_id={@slot.client_id} slot_job_id={@slot.job_id}/>
              </div>
              <hr class="my-2 md:my-3 col-span-7">
            </div>
          </div>
      <% "calendar" -> %>
        <div class="border border-base-200 rounded-lg flex p-3 my-1.5">
          <div class="flex flex-col">
            <p class="mb-1 font-bold text-black text-lg">
              <%= if @slot.status in [:booked, :reserved] do %>
                <button class="text-blue-planning-300 underline"><%= slot_time_formatter(@slot) %></button>
              <% else %>
              <%= slot_time_formatter(@slot) %>
              <% end %>
            </p>
            <p class="text-blue-planning-300 underline">
              <%= if @slot.client_id && @slot.status in [:booked, :reserved] do %>
                <button class="text-blue-planning-300 underline"><%= "Booked with " <> String.capitalize(@client.name) %></button>
              <% else %>
                <p class={classes(%{"text-base-250" => @slot.status == :hidden})}><%= String.capitalize(to_string(@slot.status)) %></p>
              <% end %>
            </p>
          </div>
          <div class="flex ml-auto">
            <.actions id={@slot_index} booking_event_date_id={@booking_event_date.id} disabled?={disable_slot_actions?(@booking_event_date, @booking_event.status)} button_actions={@button_actions} slot_index={@slot_index} slot_client_id={@slot.client_id} slot_job_id={@slot.job_id}/>
          </div>
        </div>
      <% end %>
    """
  end

  defp actions(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        archive_option: true,
        main_button_class: "text-black",
        slot_index: -1,
        slot_client_id: -1,
        slot_job_id: -1,
        disabled?: false,
        booking_event_date_id: nil
      })

    assigns =
      if assigns.slot_job_id,
        do: assigns |> Map.put(:proposal, BookingProposal.last_for_job(assigns.slot_job_id)),
        else: assigns

    ~H"""
      <div class={classes("flex items-center md:ml-auto w-full md:w-auto left-3 sm:left-8", %{"pointer-events-none opacity-40" => @disabled?})} data-placement="bottom-end" phx-hook="Select" id={"manage-client-#{@id}"}>
        <button title="Manage" class={"btn-tertiary px-2 py-1 flex items-center gap-3 xl:w-auto w-full #{@main_button_class}"}>
          Actions
          <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
          <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
        </button>

        <div class="z-10 flex flex-col hidden w-auto bg-white border rounded-lg shadow-lg popover-content">
          <%= for %{title: title, action: action, icon: icon} <- @button_actions do %>
            <%= if icon == "anchor" && BookingProposal.url(@proposal.id) do %>
              <.icon_button icon={icon} class="flex text-base-300 items-center mt-0 px-3 py-2 hover:font-bold rounded-lg" text_color={"text-black"} color="blue-planning-300" id="copy-calendar-link" phx-click={action} data-clipboard-text={BookingProposal.url(@proposal.id)} phx-hook="Clipboard">
                <span><%= title %></span>
              </.icon_button>
            <% else %>
              <.icon_button icon={icon} phx-click={action} phx-value-booking_event_date_id={@booking_event_date_id} phx-value-slot_client_id={@slot_client_id} phx-value-slot_job_id={@slot_job_id} phx-value-slot_index={@slot_index} class="flex text-base-300 items-center px-3 py-2 rounded-lg hover:font-bold" text_color={"text-black"} color={if title in ["Archive", "Disable"], do: "red-sales-300", else: "blue-planning-300"}>
                <span><%= title %></span>
              </.icon_button>
            <% end %>
          <% end %>
        </div>
      </div>
    """
  end

  defp marketing_preview(
         %{
           booking_event: %{description: event_description},
           package: package
         } = assigns
       ) do
    description =
      cond do
        event_description ->
          event_description

        package && package.description ->
          package.description

        true ->
          "Pick a package"
      end

    assigns = Map.put(assigns, :description, HtmlSanitizeEx.strip_tags(description))

    ~H"""
      <div class="rounded-lg border border-gray-300 flex flex-col p-3">
        <div class="flex items-center mb-4">
          <div class="flex items-center">
            <.icon name="marketing" class="inline-block w-5 h-5 mr-3 mt-0.5 fill-blue-planning-300" />
          </div>
          <div class="text-xl font-bold">
            Marketing preview
          </div>
        </div>
        <%= if @booking_event.thumbnail_url do %>
            <.blurred_thumbnail class="h-full items-center flex flex-col bg-base-400" url={@booking_event.thumbnail_url} />
        <% else %>
          <div class="aspect-video h-full p-6 mb-2 items-center flex flex-col bg-white">
            <div class="flex justify-center h-auto mt-6 items-center">
              <.icon name="photos-2" class="inline-block w-12 h-12 text-base-250"/>
            </div>
            <div class="mt-1 p-4 text-base-250 text-center h-full">
              <span>Edit marketing details to add a photo. Don’t forget to add a package too</span>
            </div>
          </div>
        <% end %>
        <div class="grid grid-cols-1">
          <div class="text-3xl font-bold">
            <%= @booking_event.name %>
          </div>
          <%= if @package do %>
            <div class="text-base-250 text-md">
              <%= Money.to_string(Package.price(@package)) %>
            </div>
            <div class="text-base-250 text-md">
              <%= if @package.download_count < 1, do: "No digital", else: @package.download_count %> images included <%= if Enum.any?(@booking_event.dates), do: "| #{session_info(@booking_event)} min session" %>
            </div>
            <hr class="my-3">
          <% end %>
        </div>
        <%= if @package do %>
          <%= if Enum.any?(@booking_event.dates) do %>
            <div class="flex flex-col">
              <div class="flex items-center">
                <div class="text-base-250 text-md">
                  <%= Enum.map(@booking_event.dates, fn booking_event_date -> %>
                    <.date_display date={date_formatter(booking_event_date.date)} />
                    <.address_display booking_event={booking_event_date} class="mb-4" />
                  <% end) %>
                </div>
              </div>
              <hr class="my-3">
            </div>
          <% end %>
          <div class="flex flex-col mb-3 items-start">
            <%= if package_description_length_long?(@description) do %>
              <p>
                <%= if !Enum.member?(@collapsed_sections, "Read more") do %>
                  <%= @description |> slice_description() |> raw() %>
                <% else %>
                  <%= @description %>
                <% end %>
              </p>
              <button class="mt-2 flex text-base-250 items-center justify-center" phx-click="toggle-section" phx-value-section_id="Read more">
                <%= if Enum.member?(@collapsed_sections, "Read more") do %>
                  Read less <.icon name="up" class="mt-1 w-4 h-4 ml-2 stroke-current stroke-3 text-base-250"/>
                <% else %>
                  Read more <.icon name="down" class="mt-1 w-4 h-4 ml-2 stroke-current stroke-3 text-base-250"/>
                <% end %>
              </button>
            <% else %>
              <%= @description %>
            <% end %>
          </div>
        <% else %>
          <div class="text-base-250 mt-2 mb-4">
            <p>Pick a package and update your marketing details to get started</p>
          </div>
        <% end %>
        <button phx-click="edit-marketing-event" phx-value-event-id={@booking_event.id} class="p-2 px-4 w-fit bg-base-250/20 font-bold rounded-lg">
            Edit marketing details
        </button>
      </div>
    """
  end

  defp assign_changeset(%{assigns: %{booking_event: booking_event}} = socket, params) do
    socket
    |> assign(:changeset, BookingEvent.create_changeset(booking_event, params))
  end

  defp open_wizard(socket, assigns) do
    socket
    |> open_modal(BookingEventModal, %{
      close_event: :wizard_closed,
      assigns: Enum.into(assigns, Map.take(socket.assigns, [:current_user, :booking_event]))
    })
  end

  defp disable_slot_actions?(booking_event_date, event_status) do
    event_status not in [:disabled, :archive] &&
      (is_nil(booking_event_date.date) || date_passed?(booking_event_date.date))
  end

  defp booking_slot_tabs() do
    [
      {true,
       %{
         name: "List",
         concise_name: "list",
         redirect_route: nil,
         notification_count: nil
       }},
      {true,
       %{
         name: "Calendar",
         concise_name: "calendar",
         redirect_route: nil,
         notification_count: nil
       }}
    ]
  end

  def header_actions(%{status: status}) do
    common_actions = [
      %{title: "Create marketing email", action: "send-email", icon: "envelope"},
      %{title: "Duplicate", action: "duplicate-event", icon: "duplicate-2"}
    ]

    case status do
      :active ->
        Enum.concat(common_actions, [
          %{title: "Disable", action: "confirm-disable-event", icon: "eye"},
          %{title: "Archive", action: "confirm-archive-event", icon: "trash"}
        ])

      :disabled ->
        Enum.concat(common_actions, [
          %{title: "Enable", action: "enable-event", icon: "plus"},
          %{title: "Archive", action: "confirm-archive-event", icon: "trash"}
        ])

      :archive ->
        [
          %{title: "Unarchive", action: "unarchive-event", icon: "plus"}
        ]
    end
  end

  defp date_actions(tab, booking_event, booking_event_date) do
    actions =
      if tab == "calendar",
        do: [],
        else: [
          %{
            action: "send-email",
            icon: "envelope",
            disabled:
              is_nil(booking_event_date.date) ||
                !BookingEventDates.is_booked_any_date?(
                  [booking_event_date.date],
                  booking_event_date.booking_event_id
                )
          }
        ]

    actions ++
      [
        %{
          action: "edit-date",
          icon: "pencil",
          disabled: booking_event_date.date && date_passed?(booking_event_date.date)
        },
        %{action: "duplicate-date", icon: "duplicate-2", disabled: false},
        %{
          action: "confirm-delete-date",
          icon: "trash",
          disabled:
            Enum.any?(BEShared.get_booking_event_clients(booking_event, booking_event_date.id)) ||
              (booking_event_date.date && date_passed?(booking_event_date.date))
        }
      ]
  end

  defp slot_actions(status) when status in [:open, :hidden] do
    actions =
      if status == :hidden,
        do: [%{title: "Mark open", action: "confirm-mark-open", icon: "eye"}],
        else: [%{title: "Mark hidden", action: "confirm-mark-hide", icon: "closed-eye"}]

    actions ++ [%{title: "Reserve", action: "confirm-reserve", icon: "client-icon"}]
  end

  defp slot_actions(status) when status in [:booked, :reserved] do
    actions = [
      %{title: "Go to job", action: "open-job", icon: "gallery-camera"},
      %{title: "View client", action: "open-client", icon: "client-icon"},
      %{title: "Reschedule", action: "confirm-reschedule", icon: "calendar"}
    ]

    if(status == :reserved,
      do: actions ++ [%{title: "Copy booking link", action: "link-copied", icon: "anchor"}],
      else: actions
    ) ++ [%{title: "Cancel", action: "confirm-cancel-session", icon: "cross"}]
  end

  defp package_actions do
    [
      %{title: "Replace package", action: "replace-package", icon: "package"}
    ]
  end

  defp sort_by_date(%{dates: dates} = booking_event),
    do: Map.replace(booking_event, :dates, Enum.sort(dates, :desc))

  defp slot_time_formatter(slot),
    do: Time.to_string(slot.slot_start) <> " - " <> Time.to_string(slot.slot_end)

  defp session_info(%{dates: dates}) do
    session_list =
      dates
      |> Enum.map(& &1.session_length)
      |> Enum.sort()

    "#{List.first(session_list)} - #{List.last(session_list)}"
  end

  defp date_passed?(date), do: Date.compare(date, Date.utc_today()) == :lt

  defp slice_description(description) do
    if String.length(description) > 100 do
      String.slice(description, 0..100) <> "..."
    else
      description
    end
  end
end