defmodule PicselloWeb.LeadLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, BookingProposal, Notifiers.ClientNotifier, Questionnaire}

  @impl true
  def mount(%{"id" => job_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign(stripe_status: :loading, include_questionnaire: true)
    |> assign_job(job_id)
    |> assign_proposal()
    |> ok()
  end

  @impl true
  def handle_event("add-package", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.PackageLive.NewComponent,
        assigns |> Map.take([:current_user, :job])
      )
      |> noreply()

  @impl true
  def handle_event(
        "finish-proposal",
        %{},
        socket
      ),
      do: socket |> PicselloWeb.LeadLive.ProposalMessageComponent.open_modal() |> noreply()

  @impl true
  def handle_event(
        "manage",
        %{},
        socket
      ),
      do: socket |> PicselloWeb.LeadLive.ManageLeadComponent.open_modal() |> noreply()

  @impl true
  def handle_event(
        "toggle-questionnaire",
        %{},
        %{assigns: %{include_questionnaire: include_questionnaire}} = socket
      ) do
    socket
    |> assign(:include_questionnaire, !include_questionnaire)
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  @impl true
  def handle_info({:stripe_status, status}, socket),
    do: socket |> assign(:stripe_status, status) |> noreply()

  @impl true
  def handle_info(
        {:message_composed, message_changeset},
        %{assigns: %{job: job, include_questionnaire: include_questionnaire}} = socket
      ) do
    questionnaire_id =
      if include_questionnaire, do: job |> Questionnaire.for_job() |> Repo.one() |> Map.get(:id)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :proposal,
        BookingProposal.create_changeset(%{job_id: job.id, questionnaire_id: questionnaire_id})
      )
      |> Ecto.Multi.insert(:message, fn changes ->
        message_changeset |> Ecto.Changeset.put_change(:proposal_id, changes.proposal.id)
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{proposal: proposal, message: message}} ->
        %{client: client} = job |> Repo.preload(:client)
        ClientNotifier.deliver_booking_proposal(message, client.email)

        socket
        |> assign_proposal()
        |> PicselloWeb.LeadLive.ProposalMessageSentComponent.open_modal()
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to create booking proposal. Please try again.")
        |> noreply()
    end
  end

  @impl true
  def handle_info(:archive, %{assigns: %{job: job}} = socket) do
    case job |> Job.archive_changeset() |> Repo.update() do
      {:ok, job} ->
        socket
        |> assign_job(job.id)
        |> close_modal()
        |> put_flash(:info, "Lead archived")
        |> noreply()

      {:error, _} ->
        socket
        |> close_modal()
        |> put_flash(:error, "Failed to archive lead. Please try again.")
        |> noreply()
    end
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared

  defdelegate assign_job(socket, job_id), to: PicselloWeb.JobLive.Shared
  defdelegate assign_proposal(socket), to: PicselloWeb.JobLive.Shared
end
