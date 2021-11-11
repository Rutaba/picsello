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
    <div class="p-4">
      <h1>Manage Categories</h1>
      <div class="grid grid-cols-6 gap-2 items-center">
        <div>WHCC ID</div>
        <div>WHCC Name</div>
        <div>hidden</div>
        <div>icon</div>
        <div>name</div>
        <div>position</div>
        <%= for({_, %{category: %{whcc_id: whcc_id, whcc_name: whcc_name}, changeset: changeset}} <- Enum.sort_by(@rows, &elem(&1,0))) do %>
          <div><%= whcc_name %></div>
          <div><%= whcc_id %></div>

          <.form let={f} for={changeset} class="col-span-4 grid gap-2 grid-cols-4 items-center" phx-change="save" id={"form-#{whcc_id}"}>
            <%= hidden_input f, :id %>
            <%= checkbox f, :hidden, class: "checkbox", phx_debounce: 200 %>
            <%= input f, :icon, phx_debounce: 200 %>
            <%= input f, :name, phx_debounce: 200 %>
            <%= input f, :position, type: :number_input, class: "w-20", phx_debounce: 200 %>
          </.form>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("save", params, socket) do
    socket
    |> update_row(params, fn %{category: category}, params ->
      case category |> Category.changeset(params) |> Repo.update() do
        {:ok, category} -> %{category: category, changeset: Category.changeset(category)}
        {:error, changeset} -> %{category: category, changeset: changeset}
      end
    end)
    |> noreply()
  end

  defp update_row(%{assigns: %{rows: rows}} = socket, %{"category" => %{"id" => id} = params}, f) do
    socket
    |> assign(rows: Map.update!(rows, String.to_integer(id), &f.(&1, Map.drop(params, ["id"]))))
  end

  defp assign_rows(socket) do
    socket
    |> assign(
      rows:
        Category.active()
        |> Query.order_by([c], c.id)
        |> Repo.all()
        |> Enum.map(&{&1.id, %{category: &1, changeset: Category.changeset(&1)}})
        |> Enum.into(%{})
    )
  end
end
