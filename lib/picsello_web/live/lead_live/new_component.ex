defmodule PicselloWeb.JobLive.NewComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.{Job, Repo, Client}
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

    old_client =
      Repo.get_by(Client,
        email: job.client.email |> String.downcase(),
        organization_id: current_user.organization_id
      )

    case Ecto.Multi.new()
         |> maybe_upsert_client(old_client, job.client, current_user.organization_id)
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

  defp maybe_upsert_client(
         multi,
         %Client{id: id, name: name, phone: phone} = old_client,
         new_client,
         _organization_id
       )
       when id != nil and (name == nil or phone == nil) do
    attrs =
      old_client
      |> Map.take([:name, :phone])
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Enum.into(%{name: new_client.name, phone: new_client.phone})

    Ecto.Multi.update(multi, :client, Client.edit_contact_changeset(old_client, attrs))
  end

  defp maybe_upsert_client(multi, %Client{id: id} = old_client, _new_client, _organization_id)
       when id != nil do
    Ecto.Multi.put(multi, :client, old_client)
  end

  defp maybe_upsert_client(multi, nil = _old_client, new_client, organization_id) do
    Ecto.Multi.insert(
      multi,
      :client,
      new_client
      |> Map.take([:name, :email, :phone])
      |> Map.put(:organization_id, organization_id)
      |> Client.create_changeset()
    )
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
