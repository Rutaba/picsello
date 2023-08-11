defmodule PicselloWeb.Live.Calendar.SingleBookingEvents do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:collapsed_sections, [])
    |> assign(:list_or_calendar, "Calendar")
    |> ok()
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

  def handle_event("list_or_calendar", %{"choice" => choice}, socket) do
    socket
    |> assign(:list_or_calendar, choice)
    |> noreply()
  end

  def actions_button(assigns) do
    ~H"""
    <div class={"#{@type |> String.capitalize() == "Heading" && "ml-auto"} #{@type |> String.capitalize() == "Package" && "h-8"} #{@type |> String.capitalize() |> String.contains?(["Open", "Booked (hidden)", "Booked"]) && "h-8 flex justify-end"} "} data-offset="0" phx-hook="Select" id="id">
      <button {testid("actions")} class={"btn-tertiary px-3 #{@type |> String.capitalize() == "Heading" && "h-10"} py-1.5 flex items-center gap-3 text-black xl:w-auto w-full #{@type |> String.capitalize() |> String.contains?(["Open", "Booked (hidden)", "Booked", "Package"]) && "h-8"}"}>
      Actions
      <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
      <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
      </button>
      <%= case @type |> String.capitalize() do %>
      <% "Heading" -> %>
        <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content" style="z-index: 2147483001;">
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name="envelope" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
              Create marketing email
          </button>
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name="duplicate_2" class="inline-block w-4 h-4 mt-1 mr-3 fill-blue-planning-300" />
              Duplicate
          </button>
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
              <.icon name="eye" class="inline-block w-4 h-4 mr-3 text-red-sales-300" />
              Disable
          </button>
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
              <.icon name="trash" class="inline-block w-4 h-4 mr-3 text-red-sales-300" />
              Archive
          </button>
        </div>
      <% "Open" -> %>
        <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content" style="z-index: 2147483001;">
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name="closed-eye" class="inline-block w-4 h-4 mr-3 text-blue-planning-300" />
              Mark hidden
          </button>
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name="client-icon" class="inline-block w-4 h-4 mt-1 mr-3 text-blue-planning-300" />
              Reserve
          </button>
        </div>
      <% "Booked (hidden)" -> %>
        <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content" style="z-index: 2147483001;">
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name="eye" class="inline-block w-4 h-4 mr-3 text-blue-planning-300" />
              Mark open
          </button>
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name="client-icon" class="inline-block w-4 h-4 mt-1 mr-3 text-blue-planning-300" />
              Reserve
          </button>
        </div>
      <% "Booked" -> %>
        <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content" style="z-index: 2147483001;">
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name="gallery-camera" class="inline-block w-4 h-4 mr-3 fill-blue-planning-300" />
              Go to job
          </button>
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
              <.icon name="client-icon" class="inline-block w-4 h-4 mt-1 mr-3 text-blue-planning-300" />
              View client
          </button>
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
              <.icon name="calendar" class="inline-block w-4 h-4 mr-3 text-blue-planning-300" />
              Reschedule
          </button>
          <button class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
              <.icon name="cross" class="inline-block w-4 h-4 mr-3 text-red-sales-300" />
              Cancel
          </button>
        </div>
      <% "Package" -> %>
          <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content" style="z-index: 2147483001;">
            <button class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                <.icon name="package" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                Replace package
            </button>
          </div>
      <% end %>
    </div>
    """
  end

  # requires 1) Mode 2) Time 3) Status 4) ClientName
  def slots_description(assigns) do
    ~H"""
      <%= if @mode do %>
        <div class="border-2 border-base-200 rounded-lg flex p-3 items-center my-1.5">
          <div class="flex flex-col">
            <p class={"mb-1 font-bold text-black text-lg"}>
              <%= if @status |> String.capitalize() == "Booked" do %>
                <button class="text-blue-planning-300 underline"><%= @time %></button>
              <% else %>
                <%= @time %>
              <% end %>
            </p>
            <p class="text-blue-planning-300 underline">
              <%= if @client && @status |> String.capitalize() == "Booked" do %>
                <button class="text-blue-planning-300 underline"><%= "Booked with " <> @client |> String.capitalize() %></button>
              <% else %>
                <p class={"#{@status |> String.capitalize() == "Booked (hidden)" && "text-base-250"}"}><%= @status |> String.capitalize() %></p>
              <% end %>
            </p>
          </div>
          <div class="flex ml-auto">
              <.actions_button type={@status}/>
          </div>
        </div>
      <% else %>
        <div class="grid grid-cols-7 items-center">
          <div class={"col-span-2 #{@status |> String.capitalize() == "Booked (hidden)" && "text-base-250"}"}>
              <%= if @status |> String.capitalize() == "Booked" do %>
                <button class="text-blue-planning-300 underline"><%= @time %></button>
              <% else %>
                <%= @time %>
              <% end %>
          </div>
          <div class={"col-span-2 #{@status |> String.capitalize() != "Open" && "text-base-250"}"}>
              <%= @status |> String.capitalize() %>
          </div>
          <div class="col-span-2">
              <%= if @client && @status |> String.capitalize() == "Booked" do %>
                <button class="text-blue-planning-300 underline"><%= @client |> String.capitalize() %></button>
              <% else %>
                      -
              <% end %>
          </div>
          <.actions_button type={@status}/>
          <hr class="my-3 col-span-7">
        </div>
      <% end %>
    """
  end
end
