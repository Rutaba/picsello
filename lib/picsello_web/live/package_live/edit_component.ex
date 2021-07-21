defmodule PicselloWeb.PackageLive.EditComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Package, Repo, Job}

  @impl true
  def mount(socket) do
    socket
    |> assign(template_id_value: [])
    |> ok()
  end

  @impl true
  def update(%{job: %{id: job_id, package_id: package_id}} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:shoot_count, fn ->
      job_id
      |> Picsello.Shoot.for_job()
      |> Repo.aggregate(:count)
    end)
    |> assign_new(:package, fn ->
      Repo.get!(Package, package_id)
    end)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_event(
        "validate",
        %{
          "package" => %{"package_template_id" => "new"} = package
        },
        socket
      ),
      do:
        handle_event(
          "validate",
          %{"package" => Map.drop(package, ["package_template_id"])},
          assign(socket, template_id_value: [value: "new"])
        )

  @impl true
  def handle_event(
        "validate",
        %{
          "_target" => ["package", "package_template_id"],
          "package" => %{"package_template_id" => template_id} = package
        },
        socket
      )
      when template_id != "new" do
    %{assigns: %{package_templates: package_templates}} = socket = socket |> assign_templates()

    params =
      case package_templates |> Enum.find(&(&1.id == String.to_integer(template_id))) do
        nil ->
          %{}

        template ->
          %{"package" => template |> Map.take([:shoot_count, :price, :name, :description])}
          |> Enum.into(package)
      end

    handle_event("validate", params, assign(socket, template_id_value: []))
  end

  @impl true
  def handle_event("validate", %{"package" => params}, socket),
    do: socket |> assign_changeset(:validate, params) |> noreply()

  @impl true
  def handle_event("save", %{"package" => params}, socket) do
    case socket |> build_changeset(params, nil) |> Repo.update() do
      {:ok, package} ->
        send(self(), {:update, %{package: package}})

        socket
        |> close_modal()
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(%{assigns: %{package: package}}, params, :validate) do
    package
    |> Package.update_changeset(params, validate_shoot_count: false)
  end

  defp build_changeset(%{assigns: %{package: package}}, params, _action) do
    package
    |> Package.update_changeset(params)
  end

  defp assign_changeset(
         %{assigns: %{shoot_count: shoot_count}} = socket,
         action \\ nil,
         params \\ %{}
       ) do
    changeset = build_changeset(socket, params, action) |> Map.put(:action, action)

    socket
    |> assign(
      changeset: changeset,
      shoot_count_options: shoot_count_options(shoot_count)
    )
    |> assign_templates()
  end

  defp assign_templates(
         %{assigns: %{current_user: current_user, shoot_count: shoot_count}} = socket
       ) do
    %{organization: %{package_templates: package_templates}} =
      current_user = current_user |> Repo.preload(organization: :package_templates)

    socket
    |> assign(
      current_user: current_user,
      package_templates: package_templates |> Enum.filter(&(&1.shoot_count >= shoot_count))
    )
  end

  defp shoot_count_options(shoot_count) when shoot_count in 0..1, do: Enum.to_list(1..5)

  defp shoot_count_options(shoot_count) do
    for(n <- 1..(shoot_count - 1), do: [key: n, value: n, disabled: true]) ++
      Enum.to_list(shoot_count..5)
  end
end
