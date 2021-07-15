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
  def preload([%{job: job} | _rest] = list_of_assigns) do
    shoots = Shoot.for_job(job.id) |> Repo.all()

    list_of_assigns
    |> Enum.with_index()
    |> Enum.map(fn {assigns, index} ->
      Map.put(assigns, :shoot, shoots |> Enum.at(index, nil))
    end)
  end

  @impl true
  def preload(list_of_assigns), do: list_of_assigns

  @impl true
  def render(assigns) do
    template =
      case assigns do
        %{shoot: nil} -> "new"
        _ -> "show"
      end

    render_template("#{template}.html", assigns)
  end

  @impl true
  def handle_event("add-shoot-details", %{}, %{assigns: assigns} = socket) do
    open_modal(
      PicselloWeb.ShootLive.NewComponent,
      assigns |> Map.take([:current_user, :job, :shoot_number])
    )

    socket |> noreply()
  end

  @impl true
  def handle_event("edit-shoot-details", %{}, %{assigns: assigns} = socket) do
    open_modal(
      PicselloWeb.ShootLive.EditComponent,
      assigns |> Map.take([:current_user, :job, :shoot, :shoot_number])
    )

    socket |> noreply()
  end
end
