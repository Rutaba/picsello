defmodule PicselloWeb.JobLive.PackageDetailsComponent do
  @moduledoc false

  defmodule View do
    @moduledoc false

    use PicselloWeb, :component_template
  end

  use PicselloWeb, :live_component
  alias Picsello.{Package, Repo}

  @impl true
  def mount(socket) do
    socket
    |> assign(edit: false)
    |> ok()
  end

  @impl true
  def update(assigns, socket) do
    socket |> assign(assigns) |> assign_changeset() |> ok()
  end

  @impl true
  def render(assigns) do
    template =
      case assigns do
        %{edit: true} -> "edit"
        %{package: nil} -> "new"
        _ -> "show"
      end

    render_template("#{template}.html", assigns)
  end

  @impl true
  def handle_event("toggle", %{}, %{assigns: %{edit: edit}} = socket) do
    socket |> assign(:edit, !edit) |> assign_changeset() |> noreply()
  end

  @impl true
  def handle_event("validate", %{"package" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event("save", %{"package" => params}, socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, package} ->
        send(self(), {:update, package: package})

        socket
        |> assign(edit: false)
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(%{assigns: %{package: package}}, params) do
    package
    |> Package.update_changeset(params)
  end

  defp assign_changeset(%{assigns: %{package: nil}} = socket), do: socket

  defp assign_changeset(
         %{assigns: %{shoot_count: shoot_count}} = socket,
         action \\ nil,
         params \\ %{}
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    socket
    |> assign(changeset: changeset, shoot_count_options: shoot_count_options(shoot_count))
  end

  defp shoot_count_options(shoot_count) when shoot_count in 0..1, do: Enum.to_list(1..5)

  defp shoot_count_options(shoot_count) do
    for(n <- 1..(shoot_count - 1), do: [key: n, value: n, disabled: true]) ++
      Enum.to_list(shoot_count..5)
  end
end
