defmodule PicselloWeb.Shared.EditNameComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  import PicselloWeb.GalleryLive.Shared, only: [disabled?: 1]
  alias Picsello.Job

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def handle_event("click", _, socket) do
    socket
    |> assign(:edit_name, true)
    |> noreply()
  end

  @impl true
  def handle_event("close", _, socket) do
    socket
    |> assign(:edit_name, false)
    |> noreply()
  end

  @impl true
  def handle_event(event, params, %{root_pid: root_pid} = socket) do
    send(root_pid, {String.to_atom(event), params})

    socket |> noreply()
  end

  @impl true
  def render(assigns) do
    assigns = Enum.into(assigns, %{input_label: nil, main_class: "items-center gap-4"})

    ~H"""
      <div class="flex items-center mt-4 md:justify-start">
        <div class={classes("flex items-center", %{"flex-col lg:block" => @input_label})}>
        <%= live_redirect to: @back_path do %>
          <div class={classes("flex items-center justify-center rounded-full p-2.5 mt-2 mr-4 bg-base-200", %{"lg:hidden shadow-lg bg-base-100 mt-0 px-4 py-3 w-fit mb-2" => @input_label})}>
            <.icon name="back" class={classes("stroke-current w-4 h-4 stroke-2", %{"w-2 h-3 stroke-3 text-blue-planning-300" => @input_label})}/>
            <%= if @input_label do %>
              <span class="flex ml-2 items-center font-bold text-lg">Back to job</span>
            <% end %>
          </div>
        <% end %>
          <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
            <div class={classes("flex #{@main_class}", %{"hidden" => @edit_name})}>
              <p class="w-auto text-3xl font-bold text-base-300"><%= if Map.has_key?(@data, :name), do: @data.name, else: Job.name(@data) %> </p>
              <%= if @input_label do %>
                <.icon_button disabled={disabled?(@data)} phx_click="click" phx-target={@myself} class="bg-white px-2 py-1 pt-2 pb-2 mt-4 shadow-lg w-fit" color="blue-planning-300" icon="pencil">
                  Edit gallery name
                </.icon_button>
              <% else %>
                <.icon_button phx_click="click" phx-target={@myself} class="bg-gray-200 pt-2 pb-2 shadow-lg" color="blue-planning-300" icon="pencil" />
              <% end %>
            </div>
            <div class={classes("flex", %{"hidden" => !@edit_name, "flex-col" => @input_label})}>
              <%= if @input_label do %>
                <.input_label form={f} class="input-label pb-2" field={:name}>
                  <div class="py-1"><%= @input_label %><%= error_tag(f, :name) %></div>
                </.input_label>
              <% end %>
              <%= input f, :name, value: (if Map.has_key?(@data, :name), do: @data.name, else: Job.name(@data)), class: "w-full text-input" %>
              <div class="flex">
                <%= submit "Save", disabled: !@changeset.valid?, class: "ml-4 mb-2 btn-save-side-nav" %>
                <button class="flex ml-2 mb-2 px-4 py-2 mt-4 border rounded-lg shadow-lg hover:opacity-75 border-black" title="cancel" type="button" phx-click="close" phx-target={@myself}>Cancel</button>
              </div>
            </div>
          </.form>
        </div>
      </div>
    """
  end

  def edit_name_input(assigns) do
    ~H"""
      <.live_component module={__MODULE__} id={assigns[:id] || "edit_name_input"} {assigns} />
    """
  end
end
