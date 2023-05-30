defmodule PicselloWeb.Live.Admin.Shippment.Index do
  @moduledoc "update presentation characteristics of WHCC categories"
  use PicselloWeb, live_view: [layout: false]
  alias Picsello.{Repo, Shipment.Detail, Shipment.DasType}

  @all_sections [:details, :das_types]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      :changesets,
      Detail.all()
      |> Enum.sort_by(& &1.type)
      |> Enum.map(&Detail.changeset(&1))
      |> Enum.with_index(1)
    )
    |> assign(
      :das_changesets,
      DasType.all()
      |> Enum.map(&DasType.changeset(&1))
      |> Enum.with_index(1)
    )
    |> assign(:all_sections, @all_sections)
    |> assign(:section, :details)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Manage Shippent Details</h1>
    </header>
    <div class="p-4">
      <div class="grid grid-cols-2 w-fit border-2 rounded border-cyan-800">
        <%= for section <- @all_sections do %>
          <div phx-click="change_section" phx-value-name={section} class={"cursor-pointer text-sm p-1 border border-cyan-800 hover:text-white hover:bg-slate-500 #{section == @section && 'bg-slate-500 text-white'}"}>
            <%= section |> to_string() |> String.replace("_", " ") |> String.capitalize() %>
          </div>
        <% end %>
      </div>
      <div class="items-center mt-4 grid gap-6 w-full grid-cols-8">
        <.section {assigns} />
      </div>
    </div>
    """
  end

  defp section(%{section: :details} = assigns) do
    ~H"""
      <.heading values={["Type", "Order Attribute ID", "Base Charge", "Default Upcharge", "Wallart Upcharge", "Das Carrier Type"]} />

      <%= for {%{data: data} = changeset, i} <- @changesets do %>
        <div class="contents">
          <.form :let={f} for={changeset} class="contents" phx-change="save" id={"form-#{i}"}>
            <div class="col-start-1"><%= data.type %></div>
            <div><%= data.order_attribute_id %></div>

            <%= hidden_input f, :id %>
            <%= hidden_input f, :index, value: i %>

            <%= input f, :base_charge, phx_debounce: 200, step: 0.1, min: 0.0, class: "w-24" %>
            <%= inputs_for f, :upcharge, fn u -> %>
              <%= input u, :default, phx_debounce: 200, step: 0.1, min: 0.0, class: "w-24" %>
              <%= input u, :wallart, phx_debounce: 200, step: 0.1, min: 0.0, class: "w-24", disabled: data.type == :economy_usps %>
            <% end %>

            <%= select f, :das_carrier, [:mail, :parcel], phx_debounce: 200 %>
          </.form>
        </div>
      <% end %>
    """
  end

  defp section(%{section: :das_types} = assigns) do
    ~H"""
      <.heading values={["Name", "Mail Cost", "Parcel Cost"]} />

      <%= for {%{data: data} = changeset, i} <- @das_changesets do %>
        <div class="contents">
          <.form :let={f} for={changeset} class="contents" phx-change="save" id={"form-#{i}"}>
            <div class="col-start-1"><%= data.name %></div>

            <%= hidden_input f, :id %>
            <%= hidden_input f, :index, value: i %>

            <%= input f, :mail_cost, phx_debounce: 200, step: 0.1, min: 0.0, class: "w-24" %>
            <%= input f, :parcel_cost, phx_debounce: 200, step: 0.1, min: 0.0, class: "w-24" %>
          </.form>
        </div>
      <% end %>
    """
  end

  defp heading(assigns) do
    ~H"""
    <%= for value <- @values do %>
      <div class="font-bold"><%= value %></div>
    <% end %>
    """
  end

  @impl true
  def handle_event(
        "save",
        %{"detail" => params},
        %{assigns: %{section: :details, changesets: changesets}} = socket
      ) do
    socket
    |> assign(:changesets, roll_and_update(changesets, params, &update_detail/2))
    |> noreply
  end

  def handle_event(
        "save",
        %{"das_type" => params},
        %{assigns: %{section: :das_types, das_changesets: changesets}} = socket
      ) do
    socket
    |> assign(:das_changesets, roll_and_update(changesets, params, &update_das/2))
    |> noreply
  end

  def handle_event("change_section", %{"name" => section}, socket) do
    socket
    |> assign(:section, String.to_atom(section))
    |> noreply
  end

  defp roll_and_update(changesets, %{"index" => index} = params, fun) do
    index = String.to_integer(index)

    Enum.map(
      changesets,
      fn
        {_c, ^index} = changeset -> fun.(changeset, params)
        changeset -> changeset
      end
    )
  end

  defp update_detail({changeset, i}, params) do
    case Detail.changeset(changeset.data, params) |> Repo.update() do
      {:ok, detail} -> {Detail.changeset(detail), i}
      {:error, changeset} -> {changeset, i}
    end
  end

  defp update_das({changeset, i}, params) do
    case DasType.changeset(changeset.data, params) |> Repo.update() do
      {:ok, das} -> {DasType.changeset(das), i}
      {:error, changeset} -> {changeset, i}
    end
  end
end
