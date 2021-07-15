defmodule PicselloWeb.JobLive.ShootDetailsComponent do
  @moduledoc false

  defmodule View do
    @moduledoc false

    use PicselloWeb, :component_template
    alias Picsello.Shoot
  end

  use PicselloWeb, :live_component
  alias Picsello.{Shoot, Repo}

  @impl true
  def preload([%{job_id: job_id} | _rest] = list_of_assigns) do
    shoots = Shoot.for_job(job_id) |> Repo.all()

    list_of_assigns
    |> Enum.with_index()
    |> Enum.map(fn {assigns, index} ->
      Map.put(assigns, :shoot, shoots |> Enum.at(index, nil))
    end)
  end

  def preload(list_of_assigns), do: list_of_assigns

  @impl true
  def mount(socket) do
    socket
    |> assign(open: false)
    |> ok()
  end

  @impl true
  def update(assigns, socket) do
    socket = socket |> assign(assigns)

    socket
    |> assign(:changeset, socket |> build_changeset())
    |> ok()
  end

  @impl true
  def render(assigns) do
    template =
      case assigns do
        %{open: true} -> "edit"
        %{open: false, shoot: nil} -> "new"
        _ -> "show"
      end

    render_template("#{template}.html", assigns)
  end

  @impl true
  def handle_event("toggle", %{}, %{assigns: %{open: open}} = socket) do
    socket |> assign(:open, !open) |> noreply()
  end

  @impl true
  def handle_event("validate", %{"shoot" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("save", %{"shoot" => params}, socket) do
    socket
    |> assign(
      case socket |> build_changeset(params) |> Repo.update() do
        {:ok, shoot} ->
          send(self(), {:update_shoot_count, :inc})
          [shoot: shoot, open: false]

        {:error, changeset} ->
          [changeset: changeset]
      end
    )
    |> noreply()
  end

  defp build_changeset(socket, params \\ %{})

  defp build_changeset(%{assigns: %{shoot: nil}}, _params), do: nil

  defp build_changeset(%{assigns: %{shoot: shoot}}, params) do
    shoot
    |> Shoot.update_changeset(params)
  end

  defp assign_changeset(
         socket,
         params,
         action
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end
end
