defmodule PicselloWeb.SearchComponent do
  @moduledoc "search for a field from a list of fields"
  use PicselloWeb, :live_component

  import PicselloWeb.LiveModal, only: [close_x: 1]

  @default_assigns %{
    close_label: "Close",
    save_label: "Save",
    placeholder: "Search",
    show_search: true,
    subtitle: nil,
    search_label: nil,
    submit_event: :submit,
    change_event: :change,
    title: nil,
    warning_note: nil,
    empty_result_description: "No results",
    confirm_event: nil,
    confirm_label: nil,
    secondary_btn_label: nil,
    secondary_btn_event: nil
  }

  @products_currency Picsello.Product.currency()

  @impl true
  def update(new_assigns, %{assigns: assigns} = socket) do
    assigns = Map.drop(assigns, [:flash, :myself]) |> Enum.into(@default_assigns)

    socket
    |> assign(assigns)
    |> assign(new_assigns)
    |> assign_new(:results, fn -> [] end)
    |> assign_new(:search, fn -> nil end)
    |> assign_new(:selection, fn -> nil end)
    |> assign_new(:show_warning?, fn -> false end)
    |> assign_new(:component_used_for, fn -> nil end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dialog modal">
      <.close_x />

      <h1 class="text-3xl font-bold">
        <%= @title %>
      </h1>

      <%= if @subtitle do %>
        <p class="pt-4 text-gray-400"><%= raw (@subtitle) %></p>
      <% end %>

      <%= if @component_used_for == :booking_events_search  do %>
        <%= if Map.has_key?(@payload, :client_name) do %>
          <%= if @payload.client_name do %>
            <div class="flex items-center mt-6 mb-8">
              <.icon name={@payload.client_icon} class="mt-2 w-6 h-6 text-blue-planning-300" />
              <p class="text-normal font-semibold ml-3">
                <%= @payload.client_name %>
              </p>
            </div>
          <% end %>
        <% else %>
          <div class="flex flex-col mt-6 mb-6">
            <div class="flex items-center">
              <.icon name={@icon} class="w-7 h-7 text-blue-planning-300" />
              <p class="text-sm font-semibold ml-2">
                <%= date_formatter(@payload.booking_event_date.date, :day) %>
              </p>
            </div>
            <p class="text-sm font-semibold ml-8">
              <%= @payload.slot.slot_start %> - <%= @payload.slot.slot_end %>
            </p>
          </div>
        <% end %>
      <% end %>

      <%= if @show_search do %>
        <.form :let={f} for={%{}} phx-change="change" phx-submit="submit" phx-target={@myself} class="mt-2">
          <%= if @search_label do %>
            <h1 class="font-extrabold pb-2"><%= @search_label %></h1>
          <% end %>
          <div class="flex flex-col justify-between items-center px-1.5 md:flex-row">
            <div class="relative flex w-full">
                <a href='#' class="absolute top-0 bottom-0 flex flex-row items-center justify-center overflow-hidden text-xs text-gray-400 left-2">
                <%= if Enum.any?(@results) || @selection do %>
                  <span phx-click="clear-search" class="cursor-pointer" phx-target={@myself}>
                    <.icon name="close-x" class="w-4 ml-1 fill-current stroke-current stroke-2 close-icon text-blue-planning-300" />
                  </span>
                <% else %>
                  <.icon name="search" class="w-4 ml-1 fill-current" />
                <% end %>
              </a>
              <%= text_input f, :search, value: Map.get(@selection || %{}, :name), class: "form-control w-full text-input indent-6", phx_debounce: "500", placeholder: @placeholder, maxlength: (if @component_used_for == :booking_events_search, do: nil, else: 3), autocomplete: "off" %>
              <%= if Enum.any?(@results) do %>
                <div id="search_results" class="absolute top-14 w-full z-10">
                  <div class="z-50 left-0 right-0 rounded-lg border border-gray-100 shadow py-2 px-2 bg-white w-full overflow-auto max-h-48 h-fit">
                    <%= for result <- @results do %>
                      <div class="flex items-center p-2 border-b-2 hover:bg-base-200">
                        <%= radio_button f, :selection, result.id, class: "mr-5 w-5 h-5 cursor-pointer radio text-blue-planning-300" %>
                        <div class="flex flex-col">
                          <p class="text-sm font-semibold"><%= result.name %></p>
                          <%= if Map.has_key?(result, :email) do %>
                            <p class="text-sm"><%= result.email %></p>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% else %>
                <%= if @search not in [nil, ""] do %>
                  <div class="absolute top-14 w-full z-10">
                    <div class="z-50 left-0 right-0 rounded-lg border border-gray-100 cursor-pointer shadow py-2 px-2 bg-white">
                      <p class="text-sm font-bold"><%= @empty_result_description %></p>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>

          <%= if @show_warning? do %>
            <div class="bg-base-200 rounded-lg p-4 my-2">
              <span class="bg-blue-planning-300 rounded-lg px-3 py-1 font-bold text-white text-base">Note</span>
              <div class="text-base-250 font-medium mt-2">
                <%= raw(@warning_note) %>
              </div>
            </div>
          <% end %>

          <button class="w-full mt-6 font-semibold btn-primary text-lg" {%{disabled: is_nil(@selection)}} phx-disable-with="Saving&hellip;" phx-target={@myself}>
            <%= @save_label %>
          </button>
        </.form>
      <% end %>

      <%= if @confirm_event do %>
        <button class={"w-full mt-4 " <> @confirm_class} title={@confirm_label} type="button" phx-click={@confirm_event} phx-disable-with="Saving&hellip;" phx-target={@myself}>
          <%= @confirm_label %>
        </button>
      <% end %>

      <%= if @secondary_btn_label do %>
        <button class="w-full mt-2 px-6 py-3 btn-tertiary text-blue-planning-300" type="button" phx-click={@secondary_btn_event}>
          <%= @secondary_btn_label %>
        </button>
      <% end %>

      <button class="w-full mt-2 border border-current p-3 rounded-lg font-semibold text-lg" phx-click="modal" phx-value-action="close">
        <%= @close_label %>
      </button>
    </div>
    """
  end

  @impl true

  def handle_event("change", %{"_target" => ["search"], "search" => ""}, socket),
    do:
      socket
      |> assign_defaults()
      |> noreply

  def handle_event(
        "change",
        %{"_target" => ["search"], "search" => search},
        %{assigns: %{parent_pid: parent_pid, change_event: change_event}} = socket
      ) do
    send(parent_pid, {:search_event, change_event, search})

    socket
    |> noreply
  end

  def handle_event(
        "change",
        %{"_target" => ["selection"], "selection" => selection},
        %{assigns: %{results: results}} = socket
      ) do
    selection = Enum.find(results, &(to_string(&1.id) == selection))

    socket
    |> assign_defaults(selection)
    |> may_be_assign_warning()
    |> noreply
  end

  def handle_event(
        "submit",
        _,
        %{
          assigns: %{
            parent_pid: parent_pid,
            selection: selection,
            payload: payload,
            submit_event: submit_event
          }
        } = socket
      )
      when is_map(selection) do
    send(parent_pid, {:search_event, submit_event, selection, payload})

    socket
    |> noreply
  end

  def handle_event("clear-search", _, socket) do
    socket
    |> assign_defaults()
    |> may_be_assign_warning()
    |> noreply
  end

  def handle_event(_, _, socket), do: noreply(socket)

  defp assign_defaults(socket, selection \\ nil) do
    socket
    |> assign(:selection, selection)
    |> assign(:results, [])
    |> assign(:search, nil)
  end

  def may_be_assign_warning(
        %{assigns: %{selection: %{id: id}, component_used_for: :currency}} = socket
      )
      when id != @products_currency do
    socket
    |> assign(:show_warning?, true)
  end

  def may_be_assign_warning(socket), do: assign(socket, :show_warning?, false)

  @spec open(Phoenix.LiveView.Socket.t(), %{
          optional(:close_label) => binary,
          optional(:save_label) => binary,
          optional(:subtitle) => binary,
          optional(:search_label) => binary,
          optional(:warning_note) => binary,
          optional(:empty_result_description) => binary,
          optional(:change_event) => atom(),
          optional(:submit_event) => atom(),
          optional(:selection) => map(),
          optional(:component_used_for) => atom(),
          optional(:show_warning?) => atom(),
          optional(:placeholder) => binary,
          optional(:show_search) => boolean,
          optional(:confirm_event) => binary,
          optional(:confirm_label) => binary,
          title: binary
        }) :: Phoenix.LiveView.Socket.t()
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
