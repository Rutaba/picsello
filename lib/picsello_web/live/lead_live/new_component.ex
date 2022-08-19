defmodule PicselloWeb.JobLive.NewComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.{Job, Jobs, Repo}
  import PicselloWeb.JobLive.Shared, only: [job_form_fields: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_job_types()
    |> then(fn socket ->
      if socket.assigns[:changeset] do
        socket
      else
        assign_changeset(socket, %{
          "client" =>
            Map.take(assigns, [:email, :name, :phone])
            |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
            |> Enum.into(%{})
        })
      end
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    assigns = assigns |> Enum.into(%{email: nil, name: nil, phone: nil})

    ~H"""
      <div class="flex flex-col modal">
        <div class="flex items-start justify-between flex-shrink-0">
          <h1 class="mb-4 text-3xl font-bold">Create a lead</h1>

          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
        </div>

        <.form for={@changeset} let={f} phx-change="validate" phx-submit="save" phx-target={@myself}>
          <.job_form_fields form={f} job_types={@job_types} name={@name} email={@email} phone={@phone} />

          <PicselloWeb.LiveModal.footer disabled={!@changeset.valid?} />
        </.form>
      </div>
    """
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  @impl true
  def handle_event("save", %{"job" => params}, %{assigns: %{current_user: current_user}} = socket) do
    job = socket |> build_changeset(params) |> Ecto.Changeset.apply_changes()

    case Ecto.Multi.new()
         |> Jobs.maybe_upsert_client(job.client, current_user)
         |> Ecto.Multi.insert(
           :lead,
           &Job.create_changeset(%{type: job.type, notes: job.notes, client_id: &1.client.id})
         )
         |> Repo.transaction() do
      {:ok, %{lead: %Job{id: job_id}}} ->
        socket |> push_redirect(to: Routes.job_path(socket, :leads, job_id)) |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(
         %{assigns: %{current_user: current_user}},
         params
       ) do
    params
    |> put_in(["client", "organization_id"], current_user.organization_id)
    |> Job.create_changeset()
  end

  defp assign_changeset(socket, params) do
    changeset =
      socket
      |> build_changeset(params)
      |> Map.put(:action, :validate)

    assign(socket, changeset: changeset)
  end

  defp assign_job_types(%{assigns: %{current_user: %{organization: organization}}} = socket) do
    socket
    |> assign_new(:job_types, fn ->
      (organization.profile.job_types ++ [Picsello.JobType.other_type()]) |> Enum.uniq()
    end)
  end
end
