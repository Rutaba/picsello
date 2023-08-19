defmodule PicselloWeb.Live.Calendar.BookingEvents.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  alias Picsello.{Repo, BookingEvents, Package, BookingEventDate}

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
    booking_event =
      BookingEvents.get_booking_event!(organization_id, to_integer(event_id))
      |> Repo.preload([
        :dates,
        package_template: [:package_payment_schedules, :contract, :questionnaire_template]
      ])
      |> Map.merge(%{
        # please remove them when real implementaiton is complete
        slots: [
          %{id: 1, title: "Open", status: "open", time: "4:45am - 5:00am"},
          %{id: 2, title: "Booked", status: "booked", time: "4:45am - 5:20am"},
          %{id: 3, title: "Booked (hidden)", status: "booked_hidden", time: "4:45am - 5:15am"}
        ]
      })

    socket
    |> assign(:booking_event, booking_event)
    |> assign(:payments_description, payments_description(booking_event))
    |> assign(:package, booking_event.package_template)
    |> assign(:client, %{id: 1, name: "hammad"})
    |> assign(:booking_slot_tab_active, "list")
    |> assign(:booking_slot_tabs, booking_slot_tabs())
    |> noreply()
  end

  @impl true
  def handle_params(_, _, socket) do
    socket |> noreply()
  end

  @impl true
  def handle_event("add-date", _, %{assigns: %{booking_event: booking_event}} = socket) do
    booking_date = %BookingEventDate{id: nil, booking_event_id: booking_event.id}

    socket
    |> open_wizard(%{booking_date: booking_date})
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-date",
        %{"index" => index},
        %{assigns: %{booking_event: booking_event}} = socket
      ) do
    booking_date = booking_event |> Map.get(:dates, []) |> Enum.at(to_integer(index))

    socket
    |> open_wizard(%{booking_date: booking_date})
    |> noreply()
  end

  @impl true
  def handle_event("change-booking-slot-tab", %{"tab" => tab}, socket) do
    if tab == "calendar" and socket.assigns.booking_event.dates == [] do
      socket |> noreply()
    else
      socket
      |> assign(:booking_slot_tab_active, tab)
      |> assign_tab_data(tab)
      |> noreply()
    end
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
    |> assign_tab_data(tab)
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle-section",
        %{"section_id" => section_id},
        %{assigns: %{collapsed_sections: collapsed_sections}} = socket
      ) do
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
  def handle_info({:wizard_closed, _modal}, %{assigns: assigns} = socket) do
    assigns
    |> Map.get(:flash, %{})
    |> Enum.reduce(socket, fn {kind, msg}, socket -> put_flash(socket, kind, msg) end)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:update, %{package: package}},
        %{assigns: %{booking_event: booking_event}} = socket
      ) do
    package_template =
      package
      |> Repo.preload([:package_payment_schedules, :contract, :questionnaire_template],
        force: true
      )

    booking_event = %{
      booking_event
      | package_template: package_template,
        package_template_id: package_template.id,
        # please remove them when real implementaiton is complete
        slots: [
          %{id: 1, title: "Open", status: "open", time: "4:45am - 5:00am"},
          %{id: 2, title: "Booked", status: "booked", time: "4:45am - 5:20am"},
          %{id: 3, title: "Booked (hidden)", status: "booked_hidden", time: "4:45am - 5:15am"}
        ]
    }

    socket
    |> assign(booking_event: booking_event)
    |> assign(package: package_template)
    |> assign(:payments_description, payments_description(booking_event))
    |> put_flash(:success, "Package details saved sucessfully.")
    |> noreply()
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared

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
    assigns = assigns |> Enum.into(%{status: nil, uses: 0})

    ~H"""
      <div class="flex mt-2">
        <div class="">
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
              <.icon_button icon="eye" color="blue-planning-300" class="border-2 border-base-250/20 bg-base-200 hover:border-base-250 h-8 w-8"/>
            <% else %>
              <.icon_button icon="closed-eye" color="red-sales-300" class="border-2 border-base-250/20 bg-base-200 hover:border-base-250 h-8 w-8"/>
            <% end %>
            <.icon_button icon="trash" color="red-sales-300" class="border-2 border-base-250/20 bg-base-200 hover:border-base-250 h-8 w-8"/>
          </div>
        </div>
      </div>
    """
  end

  defp booking_slot_tabs_content(%{assigns: assigns}) do
    ~H"""
    <div>
      <%= case @booking_slot_tab_active do %>
      <% "list" -> %>
        <div class="mt-10 p-3 border-2 border-base-200 rounded-lg">
          <%= if @booking_event.dates != [] do %>
            <div class="flex mb-1 items-start">
              <div class="text-2xl font-bold pr-2">Thursday, March 29th, 2023</div>
              <button class="flex text-blue-planning-300 ml-auto items-center justify-center whitespace-nowrap mt-1" phx-click="toggle-section" phx-value-section_id="first">
                View details
                <%= if !Enum.member?(@collapsed_sections, "first") do %>
                  <.icon name="down" class="mt-1.5 md:mt-1 w-4 h-4 ml-2 stroke-current stroke-3 text-blue-planning-300"/>
                <% else %>
                  <.icon name="up" class="mt-1.5 md:mt-1 w-4 h-4 ml-2 stroke-current stroke-3 text-blue-planning-300"/>
                <% end %>
              </button>
            </div>
            <div class="flex">
              <p class="text-blue-planning-300 mr-4"><b>0</b> bookings</p>
              <p class="text-blue-planning-300 mr-4"><b>12</b> available</p>
              <p class="text-blue-planning-300"><b>1</b> hidden</p>
            </div>
            <hr class="block md:hidden my-2">
            <%= if Enum.member?(@collapsed_sections, "first") do %>
              <div class="hidden md:grid grid-cols-7 border-b-4 border-blue-planning-300 font-bold text-lg my-4">
                <div class="col-span-2">Time</div>
                <div class="col-span-2">Status</div>
                <div class="col-span-2">Client</div>
              </div>
              <.render_slots {assigns} />
              <div class="flex justify-end gap-2">
                <.icon_button icon="envelope" color="blue-planning-300"/>
                <.icon_button icon="pencil" color="blue-planning-300" phx-click="edit-date" phx-value-index={0}/>
                <.icon_button icon="duplicate-2" color="blue-planning-300"/>
                <.icon_button icon="trash" color="red-sales-300"/>
              </div>
            <% end %>
          <% else %>
            <div class="font-bold text-base-250 text-xl flex items-center justify-center p-3 opacity-50"> <div> Pick a package and add a date </div> </div>
          <% end %>
        </div>
      <% "calendar" -> %>
        <div class="mt-10 pr-5 grid grid-cols-1 md:grid-cols-5 gap-5">
          <div class="md:col-span-2 bg-base-200">Calender area</div>
          <div class="md:col-span-3 flex flex-col justify-center">
            <div class="flex">
              <div class="flex text-2xl font-bold">September 15th, 2023</div>
              <div class="flex justify-end ml-auto">
                <div class="flex items-center justify-center w-8 h-8 bg-base-200 rounded-lg p-1 ml-2 mt-1">
                  <.icon name="pencil" class="w-4 h-4 fill-blue-planning-300" />
                </div>
                <div class="flex items-center justify-center w-8 h-8 bg-base-200 rounded-lg p-1 ml-2 mt-1">
                  <.icon name="duplicate-2" class="w-4 h-4 fill-blue-planning-300" />
                </div>
                <div class="flex items-center justify-center w-8 h-8 bg-base-200 rounded-lg p-1 ml-2 mt-1">
                  <.icon name="trash" class="w-4 h-4 text-red-sales-300" />
                </div>
              </div>
            </div>
            <div class="flex mt-2">
              <p class="text-blue-planning-300 mr-4"><b>0</b> bookings</p>
              <p class="text-blue-planning-300 mr-4"><b>12</b> available</p>
              <p class="text-blue-planning-300"><b>1</b> hidden</p>
            </div>
            <.render_slots {assigns} />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_slots(assigns) do
    ~H"""
    <%= for slot <- @booking_event.slots do %>
      <%= case slot.status do %>
        <% "open" -> %>
          <.slots_description client={@client} booking_event={@booking_event} booking_slot_tab_active={@booking_slot_tab_active} slot={slot} button_actions={hidden_slot_actions()} />
        <% "booked_hidden" -> %>
          <.slots_description client={@client} booking_event={@booking_event} booking_slot_tab_active={@booking_slot_tab_active} slot={slot} button_actions={open_slot_actions()} />
        <% _ -> %>
          <.slots_description client={@client} booking_event={@booking_event} booking_slot_tab_active={@booking_slot_tab_active} slot={slot} button_actions={booked_slot_actions()} />
      <% end %>
    <% end %>
    """
  end

  defp slots_description(assigns) do
    ~H"""
      <%= case @booking_slot_tab_active do %>
      <% "list" -> %>
        <div class="grid grid-cols-3 md:grid-cols-7 items-start md:items-center my-2">
          <div class="col-span-6 grid grid-cols-2 md:grid-cols-6">
            <div class={classes("col-span-2", %{"text-base-250" => @slot.status == "booked_hidden"})}>
              <%= if @slot.status == "booked" do %>
                <div class="flex gap-2 items-center">
                  <.icon name="clock-2" class="block md:hidden w-3 h-3 stroke-current text-blue-planning-300 mt-1" />
                  <button class="text-blue-planning-300 underline"><%= @slot.time %></button>
                </div>
              <% else %>
                <div class="flex gap-2 items-center">
                  <.icon name="clock-2" class="block md:hidden w-3 h-3 stroke-current text-blue-planning-300 mt-1" />
                  <div><%= @slot.time %></div>
                </div>
              <% end %>
            </div>
            <div class={classes("col-span-2", %{"text-base-250" => @slot.status != "open"})}>
              <div class="flex gap-2 items-center">
                <%= if @slot.status != "open" do %>
                  <.icon name="booked-slot" class="block md:hidden w-3 h-3 fill-blue-planning-300 mt-1.5" />
                <% else %>
                  <.icon name="open-slot" class="block md:hidden w-3 h-3 fill-blue-planning-300 mt-1.5" />
                <% end %>
                <div class=""><%= @slot.title %></div>
              </div>
            </div>
            <div class="col-span-2">
                <%= if @client && @slot.status == "booked" do %>
                  <div class="flex gap-2 items-center">
                    <.icon name="client-icon" class="block md:hidden w-3 h-3 text-blue-planning-300 mt-1.5" />
                    <div class="text-blue-planning-300 underline"><%= @client.name %></div>
                  </div>
                <% else %>
                  <div class="flex gap-2 items-center">
                    <.icon name="client-icon" class="block md:hidden w-3 h-3 text-blue-planning-300" />
                    <div class="">-</div>
                  </div>
                <% end %>
            </div>
          </div>
          <div class="justify-start">
            <.actions id={@slot.id} booking_event={@booking_event} button_actions={@button_actions} />
          </div>
          <hr class="my-2 md:my-3 col-span-7">
        </div>
      <% "calendar" -> %>
        <div class="border-2 border-base-200 rounded-lg flex p-3 my-1.5">
          <div class="flex flex-col">
            <p class="mb-1 font-bold text-black text-lg">
              <%= if @slot.status == "booked" do %>
                <button class="text-blue-planning-300 underline"><%= @slot.time %></button>
              <% else %>
                <%= @slot.time %>
              <% end %>
            </p>
            <p class="text-blue-planning-300 underline">
              <%= if @client && @slot.status == "booked" do %>
                <button class="text-blue-planning-300 underline"><%= "Booked with " <> @client.name %></button>
              <% else %>
                <p class={classes(%{"text-base-250" => @slot.status == "booked_hidden"})}><%= @slot.title %></p>
              <% end %>
            </p>
          </div>
          <div class="flex ml-auto">
            <.actions id={@slot.id} booking_event={@booking_event} button_actions={@button_actions} />
          </div>
        </div>
      <% end %>
    """
  end

  defp actions(assigns) do
    assigns = assigns |> Enum.into(%{archive_option: true, main_button_class: ""})

    ~H"""
    <div class="flex items-center md:ml-auto w-full md:w-auto left-3 sm:left-8" phx-update="ignore" data-placement="bottom-end" phx-hook="Select" id={"manage-client-#{@id}"}>
      <button {testid("actions-#{@id}")} title="Manage" class={"btn-tertiary px-2 py-1 flex items-center gap-3 text-blue-planning-300 xl:w-auto w-full #{@main_button_class}"}>
        Actions
        <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
        <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
      </button>

      <div class="z-10 flex flex-col hidden w-auto bg-white border rounded-lg shadow-lg popover-content">
        <%= if @booking_event.status == "archived" || @archive_option do %>
          <%= for %{title: title, action: action, icon: icon} <- @button_actions do %>
            <button title={title} type="button" phx-click={action} phx-value-id={@id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name={icon} class={classes("inline-block w-4 h-4 mr-3 fill-current", %{"text-red-sales-300" => icon == "trash", "text-blue-planning-300" => icon != "trash"})} />
              <%= title %>
            </button>
          <% end %>
        <% else %>
          <button title="Unarchive" type="button" phx-click="confirm-unarchive" class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
            <.icon name="plus" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300"/>
              Unarchive
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp open_wizard(socket, assigns) do
    # TODO: BookingEventModal backend functionality Currently just with minimal information
    socket
    |> open_modal(PicselloWeb.Live.Calendar.BookingEventModal, %{
      close_event: :wizard_closed,
      assigns: Enum.into(assigns, Map.take(socket.assigns, [:current_user]))
    })
  end

  defp assign_tab_data(%{assigns: %{current_user: _current_user}} = socket, tab) do
    case tab do
      "list" -> socket
      "overview" -> socket
      _ -> socket
    end
  end

  # TODO: refine logic
  defp payments_description(%{package_template: nil}), do: nil

  defp payments_description(%{
         package_template: %{package_payment_schedules: package_payment_schedules} = package
       }) do
    currency_symbol = Money.Currency.symbol!(package.currency)
    total_price = Package.price(package)
    {first_payment, remaining_payments} = package_payment_schedules |> List.pop_at(0)

    payment_count = Enum.count(remaining_payments)

    count_text =
      if payment_count > 0,
        do: ngettext(", 1 other payment", ", %{count} other payments", payment_count),
        else: nil

    if first_payment do
      interval_text =
        if first_payment.interval do
          "#{first_payment.due_interval}"
        else
          "#{first_payment.count_interval} #{first_payment.time_interval} #{first_payment.shoot_interval}"
        end

      if first_payment.percentage do
        amount = (total_price.amount / 10_000 * first_payment.percentage) |> Kernel.trunc()
        "#{currency_symbol}#{amount}.00 #{interval_text}"
      else
        "#{first_payment.price} #{interval_text}"
      end <> "#{count_text}"
    else
      nil
    end
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

  defp header_actions do
    [
      %{title: "Create marketing email", action: "open-compose", icon: "envelope"},
      %{title: "Duplicate", action: "duplicate", icon: "duplicate-2"},
      %{title: "Disable", action: "disable", icon: "eye"},
      %{title: "Archive", action: "archive", icon: "trash"}
    ]
  end

  defp booked_slot_actions do
    [
      %{title: "Go to job", action: "open-job", icon: "gallery-camera"},
      %{title: "View client", action: "open-client", icon: "client-icon"},
      %{title: "Reschedule", action: "reschedule", icon: "calendar"},
      %{title: "Cancel", action: "cancel", icon: "cross"}
    ]
  end

  defp open_slot_actions do
    [
      %{title: "Reserve", action: "reserve", icon: "client-icon"},
      %{title: "Mark hidden", action: "mark-hidden", icon: "closed-eye"}
    ]
  end

  defp hidden_slot_actions do
    [
      %{title: "Reserve", action: "reserve", icon: "client-icon"},
      %{title: "Mark open", action: "mark-open", icon: "eye"}
    ]
  end

  defp package_actions do
    [
      %{title: "Replace package", action: "replace-package", icon: "package"}
    ]
  end
end
