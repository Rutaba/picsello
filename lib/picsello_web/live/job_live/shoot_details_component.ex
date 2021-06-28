defmodule PicselloWeb.JobLive.ShootDetailsComponent do
  @moduledoc false
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

  @impl true
  def mount(socket) do
    socket
    |> assign(open: false)
    |> ok()
  end

  @impl true
  def update(assigns, socket) do
    if socket.assigns[:changeset] do
      socket |> ok()
    else
      socket
      |> assign(assigns)
      |> assign_changeset()
      |> ok()
    end
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
      case socket |> build_changeset(params) |> upsert(socket) do
        {:ok, shoot} ->
          [shoot: shoot, open: false]

        {:error, changeset} ->
          [changeset: changeset]
      end
    )
    |> noreply()
  end

  @impl true
  def handle_event("delete", _params, %{assigns: %{shoot: shoot}} = socket) do
    case Repo.delete(shoot) do
      {:ok, _} ->
        socket |> assign(open: false, shoot: nil) |> assign_changeset() |> noreply()

      {:error, _} ->
        socket |> put_flash(:error, "Failed to delete shoot. Please try again.") |> noreply()
    end
  end

  defp upsert(changeset, %{assigns: %{shoot: nil}}), do: Repo.insert(changeset)
  defp upsert(changeset, _socket), do: Repo.update(changeset)

  defp build_changeset(%{assigns: %{job_id: job_id, shoot: nil}}, params) do
    params
    |> Map.put("job_id", job_id)
    |> Shoot.create_changeset()
  end

  defp build_changeset(%{assigns: %{shoot: shoot}}, params) do
    shoot
    |> Shoot.update_changeset(params)
  end

  defp assign_changeset(
         socket,
         params \\ %{},
         action \\ nil
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end
end
