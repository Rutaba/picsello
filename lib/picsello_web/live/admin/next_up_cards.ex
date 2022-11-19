defmodule PicselloWeb.Live.Admin.NextUpCards do
  @moduledoc "Manage Next Up Cards for the app"
  use PicselloWeb, live_view: [layout: false]

  alias Picsello.{Repo, Card}

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_next_up_cards()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Manage Next Up Cards</h1>
    </header>
    <div class="p-8">
      <div class="flex items-center justify-between  mb-8">
        <div>
          <h3 class="text-2xl font-bold">Cards</h3>
          <p class="text-md">Add a card here (we still do have to run a deploy to get them to populate)</p>
        </div>
        <button class="mb-4 btn-primary" phx-click="add-card">Add card</button>
      </div>
      <%= for(%{card: %{id: id}, changeset: changeset} <- @cards) do %>
        <.form let={f} for={changeset} class="contents" phx-change="save-cards" id={"form-cards-#{id}"}>
          <%= hidden_input f, :id %>
          <div class="flex items-center gap-4 bg-gray-100 rounded-t-lg py-4 px-6">
            <h4 class="font-bold text-lg">Card—<%= input_value f, :title %></h4>
            <button title="Trash" type="button" phx-click="delete-card" class="flex items-center px-3 py-2 rounded-lg border border-red-sales-300 hover:bg-red-sales-100 hover:font-bold">
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
              <%= labeled_input f, :index, label: "Index", wrapper_class: "col-start-5", phx_debounce: "500" %>
            </div>
            <div class="flex items-center justify-between mt-8 mb-4">
              <div>
                <h3 class="text-lg font-bold">Card Buttons</h3>
                <p class="text-md">Add up to 2 buttons for your card</p>
              </div>
              <button class="btn-secondary" phx-click="add-button">Add button</button>
            </div>
            <div class="sm:grid grid-cols-2 gap-2">
              <%= inputs_for f, :buttons, [], fn fp -> %>
                <div>
                  <div class="flex items-center gap-4 bg-gray-100 rounded-t-lg py-4 px-6">
                    <h4 class="font-bold text-lg">Button</h4>
                    <button title="Trash" type="button" phx-click="delete-button" class="flex items-center px-3 py-2 rounded-lg border border-red-sales-300 hover:bg-red-sales-100 hover:font-bold">
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
  def handle_event("save-cards", params, socket) do
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
        |> order_by(desc: :inserted_at)
        |> Repo.all()
        |> Enum.map(&%{card: &1, changeset: Card.changeset(&1, %{})})
    )
  end
end
