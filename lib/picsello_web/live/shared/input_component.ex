defmodule PicselloWeb.Shared.InputComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1]

  @default_assigns %{
    close_label: "Close",
    save_event: "input_save",
    change_event: nil,
    save_label: "Save",
    input_name: "input",
    input_value: "",
    placeholder: "Please enter value",
    subtitle: nil,
    error: nil
  }

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(Enum.into(assigns, @default_assigns))
    |> ok()
  end

  @impl true
  def render(assigns) do
    assigns = Enum.into(assigns, %{class: "dialog relative"})

    ~H"""
    <div class={@class}>
      <.close_x />
      <h1 class="text-3xl font-bold">
        <%= @title %>
      </h1>

      <%= if @subtitle do %>
        <p class="pt-4"><%= raw(@subtitle) %></p>
      <% end %>

      <.section {assigns} />
    </div>
    """
  end

  defp section(assigns) do
    ~H"""
    <.form :let={f} for={%{}} phx-submit={@save_event} phx-change={@change_event} phx-target={@myself} class="mt-2">
      <%= text_input f, @input_name, value: @input_value, class: "w-full px-2 py-3 border border-slate-400 rounded-md mt-1", placeholder: @placeholder %>
      <%= if @error do %>
        <span class="text-sm text-orange-600"><%= @error %></span>
      <% end %>
      <div class="flex flex-col gap-2 mt-4">
        <button class="w-full border border-current text-center p-1.5 font-semibold bg-black text-white" disabled={!is_nil(@error)} phx-disable-with="Saving&hellip;">
          <%= @save_label %>
        </button>

        <button class="w-full border border-current text-center p-1.5 font-semibold" type="button" phx-click="modal" phx-value-action="close">
          <%= @close_label %>
        </button>
      </div>
    </.form>
    """
  end

  @impl true
  def handle_event(
        "zipcode_change",
        %{"input" => input},
        %{assigns: %{payload: payload}} = socket
      ) do
    %{zipcodes: zipcodes} = payload

    zipcodes
    |> Map.get(input)
    |> if do
      assign(socket, :error, nil)
    else
      assign(socket, :error, "Enter complete or valid zipcode")
    end
    |> noreply
  end

  def handle_event(
        event,
        params,
        %{assigns: %{parent_pid: parent_pid, payload: payload}} = socket
      ) do
    send(parent_pid, {:save_event, event, params, payload})

    socket |> noreply()
  end

  def handle_event(event, params, %{assigns: %{parent_pid: parent_pid}} = socket) do
    send(parent_pid, {:save_event, event, params})

    socket |> noreply()
  end

  @spec open(Phoenix.LiveView.Socket.t(), %{
          optional(:close_label) => binary,
          optional(:class) => binary,
          optional(:save_event) => binary,
          optional(:change_event) => binary,
          optional(:save_label) => binary,
          optional(:title) => binary,
          optional(:input_name) => binary,
          optional(:input_value) => binary,
          optional(:placeholder) => binary,
          optional(:subtitle) => binary,
          optional(:payload) => map,
          title: binary
        }) :: Phoenix.LiveView.Socket.t()
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, Map.put(assigns, :parent_pid, self()))
  end
end
