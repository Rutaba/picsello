defmodule PicselloWeb.JobLive.NewComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Ecto.Changeset
  alias Picsello.{Job, Jobs, Clients, Repo}
  import PicselloWeb.JobLive.Shared, only: [job_form_fields: 1, search_clients: 1]

  @impl true
  def update(%{current_user: current_user} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_job_types()
    |> assign(:clients, Clients.find_all_by(user: current_user))
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:searched_client, nil)
    |> assign(:new_client, false)
    |> assign(current_focus: -1)
    |> assign_new(:selected_client, fn -> nil end)
    |> then(fn socket ->
      if socket.assigns[:changeset] do
        socket
      else
        assign_job_changeset(socket, %{})
      end
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="flex flex-col modal">
        <div class="flex items-start justify-between flex-shrink-0">
          <h1 class="mb-4 text-3xl font-bold">Create a lead</h1>

          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
        </div>

        <.search_clients new_client={@new_client} search_results={@search_results} search_phrase={@search_phrase} selected_client={@selected_client} searched_client={@searched_client} current_focus={@current_focus} clients={@clients} myself={@myself}/>

        <.form for={@changeset} let={f} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <.job_form_fields form={f} job_types={@job_types} new_client={@new_client} myself={@myself} />

          <PicselloWeb.LiveModal.footer disabled={!@changeset.valid? || (!is_nil(@selected_client) && !is_nil(@searched_client) && !@new_client)} />
        </.form>
      </div>
    """
  end

  @impl true
  def handle_event("validate", %{"job" => %{"client" => _client_params} = params}, socket) do
    socket
    |> assign_changeset(params)
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{"job" => %{"type" => _job_type} = params},
        %{assigns: %{searched_client: searched_client}} = socket
      ) do
    socket
    |> assign_job_changeset(
      Map.put(
        params,
        "client_id",
        if(searched_client, do: searched_client.id, else: nil)
      )
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"job" => _params},
        %{
          assigns: %{
            current_user: current_user,
            changeset: changeset,
            selected_client: selected_client,
            searched_client: searched_client
          }
        } = socket
      ) do
    job = changeset |> Changeset.apply_changes()

    client =
      cond do
        selected_client ->
          selected_client

        searched_client ->
          searched_client

        true ->
          job.client
      end

    case Ecto.Multi.new()
         |> Jobs.maybe_upsert_client(client, current_user)
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

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  defp build_changeset(
         %{assigns: %{current_user: current_user}},
         params
       ) do
    params
    |> put_in(["client", "organization_id"], current_user.organization_id)
    |> Job.create_changeset()
    |> validate_client_email()
  end

  defp assign_changeset(socket, params) do
    changeset =
      socket
      |> build_changeset(params)
      |> Map.put(:action, :validate)

    assign(socket, changeset: changeset)
  end

  defp assign_job_changeset(socket, params) do
    changeset =
      params
      |> Job.create_changeset()
      |> Map.put(:action, :validate)

    assign(socket, :changeset, changeset)
  end

  defp validate_client_email(changeset) do
    email =
      changeset
      |> Changeset.get_field(:client)
      |> Map.get(:email)

    case Clients.already_exists?(email) do
      true ->
        Changeset.update_change(changeset, :client, fn client_changeset ->
          Changeset.add_error(client_changeset, :email, "already exists")
        end)

      _ ->
        changeset
    end
  end

  defp assign_job_types(%{assigns: %{current_user: %{organization: organization}}} = socket) do
    socket
    |> assign_new(:job_types, fn ->
      (organization.profile.job_types ++ [Picsello.JobType.other_type()]) |> Enum.uniq()
    end)
  end
end
