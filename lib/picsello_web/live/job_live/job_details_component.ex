defmodule PicselloWeb.JobLive.JobDetailsComponent do
  @moduledoc false

  defmodule View do
    @moduledoc false

    use PicselloWeb, :component_template
    alias Picsello.Job
  end

  use PicselloWeb, :live_component
  alias Picsello.{Job, Repo}

  @impl true
  def mount(socket) do
    socket
    |> assign(edit: false, changeset: nil)
    |> ok()
  end

  @impl true
  def render(assigns) do
    template =
      case assigns do
        %{edit: true} -> "edit"
        _ -> "show"
      end

    render_template("#{template}.html", assigns)
  end

  @impl true
  def handle_event("toggle", %{}, %{assigns: %{edit: edit}} = socket) do
    socket |> assign(:edit, !edit) |> assign_changeset() |> noreply()
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event("save", %{"job" => params}, socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, job} ->
        send(self(), {:updated_job, job})

        socket
        |> assign(edit: false)
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(%{assigns: %{job: job}}, params) do
    job
    |> Job.update_changeset(params)
  end

  defp assign_changeset(%{assigns: %{edit: false}} = socket), do: socket

  defp assign_changeset(
         socket,
         action \\ nil,
         params \\ %{}
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end
end
