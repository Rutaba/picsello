defmodule PicselloWeb.PackageLive.New do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Job, Repo, Package}

  @impl true
  def mount(%{"job_id" => job_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_job(job_id)
    |> assign_package_templates()
    |> maybe_redirect()
    |> assign_initial_changeset()
    |> ok()
  end

  @impl true
  def handle_event(
        "validate",
        %{
          "package" => %{"package_template_id" => package_template_id},
          "_target" => ["package", "package_template_id"]
        },
        %{assigns: %{package_templates: package_templates}} = socket
      )
      when package_template_id != "" and package_template_id != "new" do
    package = package_templates |> Enum.find(&(to_string(&1.id) == package_template_id))

    package_params = %{
      "package_template_id" => package.id,
      "name" => package.name,
      "description" => package.description,
      "price" => package.price,
      "shoot_count" => package.shoot_count
    }

    socket |> assign_changeset(package_params, :validate) |> noreply()
  end

  @impl true
  def handle_event("validate", %{"package" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("save", %{"package" => params}, %{assigns: %{job: job}} = socket) do
    changeset = build_changeset(socket, params)

    result =
      Ecto.Multi.new()
      |> maybe_create_package_template(changeset, params, socket)
      |> Ecto.Multi.insert(:package, fn changes ->
        changeset |> Ecto.Changeset.put_change(:package_template_id, changes.package_template.id)
      end)
      |> Ecto.Multi.update(:job, fn changes ->
        Job.add_package_changeset(job, %{package_id: changes.package.id})
      end)
      |> Repo.transaction()

    case result do
      {:ok, _} ->
        socket |> push_redirect(to: Routes.job_path(socket, :show, job.id)) |> noreply()

      {:error, :package_template, changeset, _} ->
        socket |> assign(changeset: changeset) |> noreply()

      {:error, :package, changeset, _} ->
        socket |> assign(changeset: changeset) |> noreply()

      {:error, :job, _changeset, _} ->
        socket |> put_flash(:error, "Oops! Something went wrong. Please try again.") |> noreply()
    end
  end

  defp maybe_create_package_template(multi, changeset, %{"package_template_id" => "new"}, _socket) do
    multi
    |> Ecto.Multi.insert(
      :package_template,
      changeset
    )
  end

  defp maybe_create_package_template(
         multi,
         _changeset,
         %{"package_template_id" => package_template_id},
         %{
           assigns: %{package_templates: package_templates}
         }
       ) do
    package_template = package_templates |> Enum.find(&(to_string(&1.id) == package_template_id))

    multi
    |> Ecto.Multi.put(:package_template, package_template)
  end

  defp assign_job(%{assigns: %{current_user: current_user}} = socket, job_id) do
    job = current_user |> Job.for_user() |> Repo.get!(job_id) |> Repo.preload(:client)

    socket |> assign(:job, job)
  end

  defp assign_package_templates(%{assigns: %{current_user: current_user}} = socket) do
    %{organization: %{package_templates: package_templates}} =
      current_user |> Repo.preload(organization: :package_templates)

    socket |> assign(:package_templates, package_templates)
  end

  defp build_changeset(
         %{assigns: %{current_user: current_user}},
         params
       ) do
    params
    |> Map.put("organization_id", current_user.organization_id)
    |> Package.create_changeset()
  end

  defp assign_initial_changeset(%{assigns: %{package_templates: package_templates}} = socket)
       when package_templates == [] do
    socket |> assign_changeset(%{"package_template_id" => "new"})
  end

  defp assign_initial_changeset(socket), do: assign_changeset(socket)

  defp assign_changeset(socket, params \\ %{}, action \\ nil) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  defp maybe_redirect(%{assigns: %{job: %{id: job_id, package_id: package_id}}} = socket)
       when package_id != nil do
    socket |> push_redirect(to: Routes.job_path(socket, :show, job_id))
  end

  defp maybe_redirect(socket), do: socket
end
