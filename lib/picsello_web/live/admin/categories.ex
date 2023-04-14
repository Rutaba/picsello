defmodule PicselloWeb.Live.Admin.Categories do
  @moduledoc "update presentation characteristics of WHCC categories"
  use PicselloWeb, live_view: [layout: false]
  alias Picsello.{Repo, Category}
  require Ecto.Query
  alias Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_rows()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Manage Categories</h1>
    </header>
    <div class="p-4">
      <div class="items-center mt-4 grid gap-6 w-full grid-cols-[repeat(10,min-content)]">
        <div class="font-bold">WHCC Name</div>
        <div class="font-bold">WHCC ID</div>
        <div class="font-bold">Coming Soon?</div>
        <div class="font-bold">hidden</div>
        <div class="font-bold">icon</div>
        <div class="font-bold">name</div>
        <div class="font-bold">default markup</div>
        <div class="font-bold">frame image</div>
        <div class="font-bold">position</div>
        <%= for(%{category: %{id: id, whcc_id: whcc_id, whcc_name: whcc_name, icon: icon}, changeset: changeset} <- @rows) do %>
          <div class="contents">
            <div class="col-start-1"><%= whcc_name %></div>
            <div><%= whcc_id %></div>

            <.form :let={f} for={changeset} class="contents" phx-change="save" id={"form-#{whcc_id}"}>
              <%= hidden_input f, :id %>
              <%= checkbox f, :coming_soon, class: "checkbox", phx_debounce: 200 %>
              <%= checkbox f, :hidden, class: "checkbox", phx_debounce: 200 %>
              <div>
                <.icon name={icon} class="w-4 h-4" />
                <%= select f, :icon, Picsello.Icon.names(), phx_debounce: 200 %>
              </div>
              <%= input f, :name, phx_debounce: 200 %>
              <%= input f, :default_markup, type: :number_input, phx_debounce: 200, step: 0.01, min: 1.0, class: "w-24" %>
              <%= select f, :frame_image, [""| Picsello.Category.frame_images()], phx_debounce: 200 %>
            </.form>

            <div class="flex text-center justify-evenly">
              <a class="flex-grow p-2 mr-2 border rounded" phx-value-id={id} phx-value-direction="up" phx-click="reorder" href="#">↑</a>
              <a class="flex-grow p-2 border rounded" phx-value-id={id} phx-value-direction="down" phx-click="reorder" href="#">↓</a>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "reorder",
        %{"direction" => direction, "id" => id},
        %{assigns: %{rows: rows}} = socket
      ) do
    reorder_id = String.to_integer(id)

    case direction do
      "up" -> Enum.reverse(rows)
      "down" -> rows
    end
    |> Enum.reduce_while([], fn
      %{category: %{id: id} = category}, [] when id == reorder_id -> {:cont, [category]}
      %{category: category}, [reorder] -> {:halt, [reorder, category]}
      _, acc -> {:cont, acc}
    end)
    |> case do
      [category_a, category_b] ->
        swap(category_a, category_b)

        socket |> assign_rows() |> noreply()

      _ ->
        socket |> noreply()
    end
  end

  @impl true
  def handle_event("save", params, socket) do
    socket
    |> update_row(params, fn category, params ->
      case category |> Category.changeset(params) |> Repo.update() do
        {:ok, category} -> %{category: category, changeset: Category.changeset(category)}
        {:error, changeset} -> %{category: category, changeset: changeset}
      end
    end)
    |> noreply()
  end

  defp update_row(%{assigns: %{rows: rows}} = socket, %{"category" => %{"id" => id} = params}, f) do
    id = String.to_integer(id)

    socket
    |> assign(
      rows:
        Enum.map(rows, fn
          %{category: %{id: ^id} = category} -> f.(category, Map.drop(params, ["id"]))
          row -> row
        end)
    )
  end

  defp swap(a, b),
    do:
      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :a,
        Ecto.Changeset.change(a, %{
          position: b.position,
          deleted_at: DateTime.truncate(DateTime.utc_now(), :second)
        })
      )
      |> Ecto.Multi.update(
        :b,
        Ecto.Changeset.change(b, %{position: a.position})
      )
      |> Ecto.Multi.update(
        :c,
        fn %{a: a} ->
          Ecto.Changeset.change(a, %{deleted_at: nil})
        end
      )
      |> Repo.transaction()

  defp assign_rows(socket) do
    socket
    |> assign(
      rows:
        Category.active()
        |> Query.order_by([c], c.position)
        |> Repo.all()
        |> Enum.map(&%{category: &1, changeset: Category.changeset(&1)})
    )
  end
end
