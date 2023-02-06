defmodule PicselloWeb.Live.Admin.NextUpCards do
  @moduledoc "Manage Next Up Cards for the app"
  use PicselloWeb, live_view: [layout: false]

  alias Picsello.{Repo, Card, OrganizationCard}

  import Ecto.Query, only: [order_by: 2, from: 2]

  import PicselloWeb.LayoutView,
    only: [
      flash: 1
    ]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_next_up_cards()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= flash(@flash) %>
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Manage Next Up Cards</h1>
    </header>
    <div class="p-8">
      <div class="flex items-center justify-between  mb-8">
        <div>
          <h3 class="text-2xl font-bold">Cards</h3>
          <p class="text-md"><span class="text-red-sales-300 font-bold block">CAREFUL deleting cards, it will remove from all organizations on Picsello!</span> Add a card here (we still do have to run a deploy to get them to populate)</p>
        </div>
        <button class="mb-4 btn-primary" phx-click="add-card">Add card</button>
      </div>
      <%= for({%{card: %{id: id, buttons: buttons}, changeset: changeset}, index} <- @cards |> Enum.with_index()) do %>
        <.form let={f} for={changeset} class="contents" phx-change="update-card" id={"form-cards-#{id}"}>
          <%= hidden_input f, :id %>
          <div class="flex items-center gap-4 bg-gray-100 rounded-t-lg py-4 px-6">
            <h4 class="font-bold text-lg">Card—<%= input_value f, :title %></h4>
            <button title="Trash" type="button" phx-click="delete-card" phx-value-id={id} class="flex items-center px-3 py-2 rounded-lg border border-red-sales-300 hover:bg-red-sales-100 hover:font-bold">
              <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
            </button>
          </div>
          <div class="p-6 border rounded-b-lg mb-8">
            <div>
              <%= labeled_input f, :title, label: "Card Title", wrapper_class: "", phx_debounce: "500" %>
            </div>
            <div>
              <%= labeled_input f, :body, label: "Card Body", wrapper_class: "", phx_debounce: "500" %>
            </div>
            <h4 class="mt-6 mb-2 font-bold text-lg">Card Options</h4>
            <div class="sm:grid grid-cols-5 gap-2 items-center">
              <%= labeled_input f, :concise_name, label: "Concise Name", wrapper_class: "col-start-1", phx_debounce: "500" %>
              <%= labeled_input f, :icon, label: "Icon", wrapper_class: "col-start-2", phx_debounce: "500" %>
              <%= labeled_input f, :color, label: "Color", wrapper_class: "col-start-3", phx_debounce: "500" %>
              <%= labeled_input f, :class, label: "Class", wrapper_class: "col-start-4", phx_debounce: "500" %>
              <%= labeled_input f, :index, type: :number_input, label: "Index", wrapper_class: "col-start-5", phx_debounce: "500" %>
            </div>
            <div class="flex items-center justify-between mt-8 mb-4">
              <div>
                <h3 class="text-lg font-bold">Card Buttons</h3>
                <p class="text-md">Add up to 2 buttons for your card</p>
              </div>
              <%= if length(buttons) < 2 do %>
              <button class="btn-secondary" phx-click="add-button" type="button" phx-value-index={index}>Add button</button>
              <% end %>
            </div>
            <div class="sm:grid grid-cols-2 gap-2">
              <%= for {fp, button_index} <- Enum.with_index(inputs_for(f, :buttons)) do %>
                <div>
                  <div class="flex items-center gap-4 bg-gray-100 rounded-t-lg py-4 px-6">
                    <h4 class="font-bold text-lg">Button</h4>
                    <button title="Trash" type="button" phx-click="delete-button" class="flex items-center px-3 py-2 rounded-lg border border-red-sales-300 hover:bg-red-sales-100 hover:font-bold" phx-value-index={index} phx-value-button-index={button_index}>
                      <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
                    </button>
                  </div>
                  <div class="p-6 border rounded-b-lg mb-8">
                    <div class="sm:grid grid-cols-3 gap-2 items-center">
                      <%= labeled_input fp, :class, label: "Class", phx_debounce: "500" %>
                      <%= labeled_input fp, :label, label: "Label", phx_debounce: "500" %>
                      <%= labeled_input fp, :external_link, label: "External Link", phx_debounce: "500" %>
                      <%= labeled_input fp, :action, label: "Action", phx_debounce: "500" %>
                      <%= labeled_input fp, :link, label: "Link", phx_debounce: "500" %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </.form>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("add-card", _, socket) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :card,
      Card.changeset(
        %Card{concise_name: "simple-card", title: "New card…", icon: "confetti-welcome"},
        %{}
      )
    )
    |> Ecto.Multi.insert(
      :organization_card,
      fn %{card: %{id: id}} ->
        OrganizationCard.changeset(%OrganizationCard{}, %{
          status: "active",
          card_id: id,
          organization_id: nil
        })
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        socket
        |> put_flash(:success, "Added card")

      {:error, _} ->
        socket
        |> put_flash(:error, "Something went wrong")
    end
    |> assign_next_up_cards()
    |> noreply()
  end

  @impl true
  def handle_event("delete-card", %{"id" => id}, socket) do
    id = String.to_integer(id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :delete_all_org_card,
      from(oc in OrganizationCard, where: oc.card_id == ^id)
    )
    |> Ecto.Multi.delete_all(
      :delete_all_card,
      from(c in Card, where: c.id == ^id)
    )
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        socket
        |> put_flash(:success, "Deleted card")

      {:error, _} ->
        socket
        |> put_flash(:error, "Something went wrong")
    end
    |> assign_next_up_cards()
    |> noreply()
  end

  @impl true
  def handle_event("update-card", params, socket) do
    socket
    |> update_cards(params, fn card, params ->
      case card |> Card.changeset(params) |> Repo.update() do
        {:ok, card} ->
          %{
            card: card,
            changeset: Card.changeset(card, %{})
          }

        {:error, changeset} ->
          %{card: card, changeset: changeset}
      end
    end)
    |> assign_next_up_cards()
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-button",
        %{"index" => index},
        %{assigns: %{cards: cards}} = socket
      ) do
    index = String.to_integer(index)

    %{card: %{buttons: buttons} = card} = Enum.at(cards, index)

    merge_buttons =
      buttons |> Enum.map(&Map.from_struct/1) |> Enum.concat([%{label: "New button…"}])

    case Card.changeset(card, %{buttons: merge_buttons}) |> Repo.update() do
      {:error, _} -> socket |> put_flash(:error, "Something went wrong")
      {:ok, _} -> socket |> put_flash(:success, "Button added")
    end
    |> assign_next_up_cards()
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete-button",
        %{"index" => index, "button-index" => button_index},
        %{assigns: %{cards: cards}} = socket
      ) do
    index = String.to_integer(index)
    button_index = String.to_integer(button_index)

    %{card: %{buttons: buttons} = card} = Enum.at(cards, index)

    new_buttons =
      buttons
      |> Enum.map(&Map.from_struct/1)
      |> List.delete_at(button_index)

    case Card.changeset(card, %{buttons: new_buttons}) |> Repo.update() do
      {:error, _} -> socket |> put_flash(:error, "Something went wrong")
      {:ok, _} -> socket |> put_flash(:success, "Button deleted")
    end
    |> assign_next_up_cards()
    |> noreply()
  end

  defp update_cards(
         %{assigns: %{cards: cards}} = socket,
         %{"card" => %{"id" => id} = params},
         card_update_fn
       ) do
    id = String.to_integer(id)

    socket
    |> assign(
      cards:
        Enum.map(cards, fn
          %{card: %{id: ^id} = card} ->
            card_update_fn.(card, Map.drop(params, ["id"]))

          _card ->
            nil
        end)
    )
  end

  defp assign_next_up_cards(socket) do
    socket
    |> assign(
      cards:
        Card
        |> order_by(desc: :index)
        |> Repo.all()
        |> Enum.map(&%{card: &1, changeset: Card.changeset(&1, %{})})
    )
  end
end
