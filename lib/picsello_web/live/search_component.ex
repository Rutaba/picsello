defmodule PicselloWeb.SearchComponent do
  @moduledoc "search for a field from a list of fields"
  use PicselloWeb, :live_component

  import PicselloWeb.LiveModal, only: [close_x: 1]

  @default_assigns %{
    close_label: "Close",
    save_label: "Save",
    subtitle: nil,
    submit_event: :submit,
    change_event: :change,
    title: nil,
    warning_note: nil,
    empty_result_description: "No results"
  }

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
        <p class="pt-4"><%= @subtitle %></p>
      <% end %>

      <.form :let={f} for={%{}} phx-change="change" phx-submit="submit" phx-target={@myself} class="mt-2">
        <h1 class="font-extrabold pb-2">Currency</h1>
        <div class="flex flex-col justify-between items-center px-1.5 md:flex-row">
          <div class="relative flex w-full">
              <a href='#' class="absolute top-0 bottom-0 flex flex-row items-center justify-center overflow-hidden text-xs text-gray-400 left-2">
              <%= if @search not in [nil, ""] && Enum.any?(@results) || @selection do %>
                <span phx-click="clear-search" class="cursor-pointer" phx-target={@myself}>
                  <.icon name="close-x" class="w-4 ml-1 fill-current stroke-current stroke-2 close-icon text-blue-planning-300" />
                </span>
              <% else %>
                <.icon name="search" class="w-4 ml-1 fill-current" />
              <% end %>
            </a>
            <%= text_input f, :search, value: Map.get(@selection || %{}, :name), class: "form-control w-full text-input indent-6", phx_debounce: "500", placeholder: "Search Currencies...", maxlength: 3, autocomplete: "off" %>
            <%= if @search not in [nil, ""] && Enum.any?(@results) do %>
              <div id="search_results" class="absolute top-14 w-4/6 z-10">
                <div class="z-50 left-0 right-0 rounded-lg border border-gray-100 shadow py-2 px-2 bg-white w-full overflow-auto max-h-48 h-fit">
                  <%= for result <- @results do %>
                    <div class="flex p-2 border-b-2 hover:bg-base-200">
                      <%= radio_button f, :selection, result.id, class: "mr-5 w-5 h-5 cursor-pointer radio text-blue-planning-300" %>
                      <p class="text-sm font-semibold"><%= result.name %></p>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <%= if @search not in [nil, ""] do %>
                <div class="absolute top-14 w-4/6 z-10">
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
        %{assigns: %{parent_pid: parent_pid, selection: selection, submit_event: submit_event}} =
          socket
      )
      when is_map(selection) do
    send(parent_pid, {:search_event, submit_event, selection})

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
      when id != "USD" do
    socket
    |> assign(:show_warning?, true)
  end

  def may_be_assign_warning(socket), do: assign(socket, :show_warning?, false)

  @spec open(Phoenix.LiveView.Socket.t(), %{
          optional(:close_label) => binary,
          optional(:save_label) => binary,
          optional(:subtitle) => binary,
          optional(:warning_note) => binary,
          optional(:empty_result_description) => binary,
          optional(:change_event) => atom(),
          optional(:submit_event) => atom(),
          optional(:selection) => map(),
          optional(:component_used_for) => atom(),
          title: binary
        }) :: Phoenix.LiveView.Socket.t()
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
