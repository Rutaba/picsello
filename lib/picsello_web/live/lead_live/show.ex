defmodule PicselloWeb.LeadLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, BookingProposal, Accounts.UserNotifier, Questionnaire}

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
  defdelegate proposal_token(proposal), to: PicselloWeb.JobLive.Shared

  @impl true
  def handle_info({:stripe_status, status}, socket),
    do: socket |> assign(:stripe_status, status) |> noreply()

  @impl true
  def handle_info(
        {:message_composed, message},
        %{assigns: %{job: job, include_questionnaire: include_questionnaire}} = socket
      ) do
    questionnaire_id =
      if include_questionnaire, do: Questionnaire.for_job(job) |> Repo.one() |> Map.get(:id)

    case BookingProposal.create_changeset(%{job_id: job.id, questionnaire_id: questionnaire_id})
         |> Repo.insert() do
      {:ok, proposal} ->
        token = proposal_token(proposal)
        url = Routes.booking_proposal_url(socket, :show, token)
        %{client: client} = job |> Repo.preload(:client)
        UserNotifier.deliver_booking_proposal(client, url, message)

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
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared

  defdelegate assign_job(socket, job_id), to: PicselloWeb.JobLive.Shared
  defdelegate assign_proposal(socket), to: PicselloWeb.JobLive.Shared
end
