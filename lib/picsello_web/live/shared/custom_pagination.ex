defmodule PicselloWeb.Shared.CustomPagination do
  @moduledoc "For setting custom pagination using limit and offset"
  use Ecto.Schema
  use PicselloWeb, :live_component

  import Ecto.Changeset

  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias Ecto.Changeset


  @primary_key false
  embedded_schema do
    field(:first_index, :integer, default: 1)
    field(:last_index, :integer, default: 0)
    field(:total_count, :integer, default: 0)
    field(:limit, :integer, default: 12)
    field(:offset, :integer, default: 0)
  end

  @attrs [:first_index, :last_index, :total_count, :limit, :offset]
  def changeset(struct \\ %__MODULE__{}, attrs \\ %{}) do
    struct
    |> cast(attrs, @attrs)
  end

  def render(assigns) do
    ~H"""
      <div id={"#{@id}-wrapper"} class="flex items-center px-6 pb-6 center-container">
      <% IO.inspect(@pagination_changeset |> Changeset.apply_changes()) %>
        <%= if pagination_index(@pagination_changeset, :total_count) > pagination_index(@pagination_changeset, :limit) do %>
          <.form let={f} for={@pagination_changeset} phx-change="page" class="flex items-center text-gray-500 rounded p-1 border cursor-pointer border-blue-planning-300">
              <%= select f, :limit, @limit_options, class: "cursor-pointer"%>
            </.form>

          <div class="flex ml-2 text-xs font-bold text-gray-500">
            Results: <%= pagination_index(@pagination_changeset, :first_index) %> – <%= pagination_index(@pagination_changeset, :last_index) %> of <%= pagination_index(@pagination_changeset, :total_count) %>
          </div>

          <div class="flex items-center ml-auto">
            <button class="flex items-center p-4 text-xs font-bold rounded disabled:text-gray-300 hover:bg-gray-100" title="Previous page" phx-click="page" phx-value-direction="back" disabled={pagination_index(@pagination_changeset, :first_index) == 1}>
              <.icon name="back" class="w-3 h-3 mr-1 stroke-current stroke-2" />
              Prev
            </button>
            <button class="flex items-center p-4 text-xs font-bold rounded disabled:text-gray-300 hover:bg-gray-100" title="Next page" phx-click="page" phx-value-direction="forth"  disabled={pagination_index(@pagination_changeset, :last_index) == pagination_index(@pagination_changeset, :total_count)}>
              Next
              <.icon name="forth" class="w-3 h-3 ml-1 stroke-current stroke-2" />
            </button>
          </div>
      <% end %>
    </div>
    """
  end

  def pagination_component(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id] || "pagination"} {assigns} />
    """
  end

  def assign_pagination(socket, default_limit),
    do:
      socket
      |> assign_new(:pagination_changeset, fn ->
        changeset(%__MODULE__{}, %{limit: default_limit})
      end)

  def update_pagination(
        %{assigns: %{pagination_changeset: pagination_changeset}} = socket,
        %{"direction" => direction}
      ) do
    pagination = pagination_changeset |> Changeset.apply_changes()

    updated_pagination =
      case direction do
        "back" ->
          pagination
          |> changeset(%{
            first_index: pagination.first_index - pagination.limit,
            offset: pagination.offset - pagination.limit
          })

        _ ->
          pagination
          |> changeset(%{
            first_index: pagination.first_index + pagination.limit,
            offset: pagination.offset + pagination.limit
          })
      end

    socket
    |> assign(:pagination_changeset, updated_pagination)
  end

  def update_pagination(
        %{assigns: %{pagination_changeset: pagination_changeset}} = socket,
        %{"custom_pagination" => %{"limit" => limit}}
      ) do
    limit = to_integer(limit)

    updated_pagination_changeset =
      %__MODULE__{}
      |> changeset(%{
        limit: limit,
        last_index: limit,
        total_count: pagination_index(pagination_changeset, :total_count)
      })

    socket
    |> assign(:pagination_changeset, updated_pagination_changeset)
  end

  def update_pagination(
        %{assigns: %{pagination_changeset: pagination_changeset}} = socket,
        params
      ),
      do:
        socket
        |> assign(
          :pagination_changeset,
          changeset(pagination_changeset, params)
        )

  def reset_pagination(
        %{assigns: %{pagination_changeset: pagination_changeset}} = socket,
        params
      ),
      do:
        socket
        |> assign(
          :pagination_changeset,
          changeset(%__MODULE__{}, params)
        )

  def pagination_index(changeset, index),
    do: changeset |> current() |> Map.get(index)
end
