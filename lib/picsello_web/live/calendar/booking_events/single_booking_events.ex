defmodule PicselloWeb.Live.Calendar.SingleBookingEvents do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:collapsed_sections, [])
    |> assign(:booking_event, %{id: 1, archived_at: nil, slots: [
      %{id: 1, title: "Open", status: "open", time: "4:45am - 5:00am"},
      %{id: 2, title: "Booked", status: "booked", time: "4:45am - 5:20am"},
      %{id: 3, title: "Booked (hidden)", status: "booked_hidden", time: "4:45am - 5:15am"}
      ]})
    |> assign(:client, %{id: 1, name: "hammad"})
    |> assign(:booking_slot_tab_active, "list")
    |> assign(:booking_slot_tabs, booking_slot_tabs())
    |> ok()
  end

  @impl true
  def handle_event("change-booking-slot-tab", %{"tab" => tab}, socket) do
    socket
    |> assign(:booking_slot_tab_active, tab)
    |> assign_tab_data(tab)
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

  def handle_event("toggle_booking_slot_tab", %{"id" => booking_slot_tab}, socket) do
    socket
    |> assign(:booking_slot_tab, booking_slot_tab)
    |> noreply()
  end

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

  defp booking_slot_tabs_content(%{assigns: assigns}) do
    ~H"""
    <div>
      <%= case @booking_slot_tab_active do %>
        <% "list" -> %>
          <div class="mt-10 p-3 border-2 border-base-200 rounded-lg">
            <div class="flex mb-1">
              <p class="text-2xl font-bold">Thursday, March 29th, 2023</p>
              <button class="flex text-blue-planning-300 ml-auto items-center justify-center" phx-click="toggle-section" phx-value-section_id="first">
                View details
                <%= if !Enum.member?(@collapsed_sections, "first") do %>
                  <.icon name="down" class="mt-1 w-4 h-4 ml-2 stroke-current stroke-3 text-blue-planning-300"/>
                <% else %>
                  <.icon name="up" class="mt-1 w-4 h-4 ml-2 stroke-current stroke-3 text-blue-planning-300"/>
                <% end %>
              </button>
            </div>
            <div class="flex">
              <p class="text-blue-planning-300 mr-4"><b>0</b> bookings</p>
              <p class="text-blue-planning-300 mr-4"><b>12</b> available</p>
              <p class="text-blue-planning-300"><b>1</b> hidden</p>
            </div>
            <%= if Enum.member?(@collapsed_sections, "first") do %>
              <div class="grid grid-cols-7 border-b-4 border-blue-planning-300 font-bold text-lg my-4">
                <div class="col-span-2">Time</div>
                <div class="col-span-2">Status</div>
                <div class="col-span-2">Client</div>
              </div>
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
            <div class="flex justify-end">
              <div class="flex items-center justify-center w-8 h-8 bg-base-200 rounded-lg p-1 ml-2 mt-2">
                <.icon name="envelope" class="w-4 h-4 text-blue-planning-300" />
              </div>
              <div class="flex items-center justify-center w-8 h-8 bg-base-200 rounded-lg p-1 ml-2 mt-2">
                <.icon name="pencil" class="w-4 h-4 fill-blue-planning-300" />
              </div>
              <div class="flex items-center justify-center w-8 h-8 bg-base-200 rounded-lg p-1 ml-2 mt-2">
                <.icon name="duplicate_2" class="w-4 h-4 fill-blue-planning-300" />
              </div>
              <div class="flex items-center justify-center w-8 h-8 bg-base-200 rounded-lg p-1 ml-2 mt-2">
                <.icon name="trash" class="w-4 h-4 text-red-sales-300" />
              </div>
            </div>
          <% end %>
        </div>
      <% "calendar" -> %>
        <div class="mt-10 pr-5 grid grid-cols-5 gap-5">
          <div class="col-span-2 bg-base-200">Calender area</div>
          <div class="col-span-3 flex flex-col justify-center">
            <div class="flex">
              <div class="flex text-2xl font-bold">September 15th, 2023</div>
              <div class="flex justify-end ml-auto">
                <div class="flex items-center justify-center w-8 h-8 bg-base-200 rounded-lg p-1 ml-2 mt-1">
                  <.icon name="pencil" class="w-4 h-4 fill-blue-planning-300" />
                </div>
                <div class="flex items-center justify-center w-8 h-8 bg-base-200 rounded-lg p-1 ml-2 mt-1">
                  <.icon name="duplicate_2" class="w-4 h-4 fill-blue-planning-300" />
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
        <div class="grid grid-cols-7 items-center">
          <div class={classes("col-span-2", %{"text-base-250" => @slot.status == "booked_hidden"})}>
              <%= if @slot.status == "booked" do %>
                <button class="text-blue-planning-300 underline"><%= @slot.time %></button>
              <% else %>
                <%= @slot.time %>
              <% end %>
          </div>
          <div class={classes("col-span-2", %{"text-base-250" => @slot.status != "Open"})}>
              <%= @slot.title %>
          </div>
          <div class="col-span-2">
              <%= if @client && @slot.status == "booked" do %>
                <button class="text-blue-planning-300 underline"><%= @client.name %></button>
              <% else %>
                      -
              <% end %>
          </div>
          <.actions id={@slot.id} booking_event={@booking_event} button_actions={@button_actions} />
          <hr class="my-3 col-span-7">
        </div>
      <% "calendar" -> %>
        <div class="border-2 border-base-200 rounded-lg flex p-3 items-center my-1.5">
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
    assigns = assigns |> Enum.into(%{archive_option: true})

    ~H"""
    <div class="flex items-center md:ml-auto w-full md:w-auto left-3 sm:left-8" phx-update="ignore" data-placement="bottom-end" phx-hook="Select" id={"manage-client-#{@id}"}>
      <button {testid("actions-#{@id}")} title="Manage" class="btn-tertiary px-2 py-1 flex items-center gap-3 mr-2 text-blue-planning-300 xl:w-auto w-full">
        Actions
        <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
        <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
      </button>

      <div class="z-10 flex flex-col hidden w-auto bg-white border rounded-lg shadow-lg popover-content">
        <%= if is_nil(@booking_event.archived_at) || @archive_option do %>
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

  defp assign_tab_data(%{assigns: %{current_user: _current_user}} = socket, tab) do
    case tab do
      "list" -> socket

      "overview" -> socket

      _ -> socket
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
      %{title: "Duplicate", action: "duplicate", icon: "duplicate_2"},
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
