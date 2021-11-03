defmodule PicselloWeb.LeadLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, BookingProposal, Notifiers.ClientNotifier, Questionnaire}

  import PicselloWeb.JobLive.Shared,
    only: [
      assign_job: 2,
      assign_proposal: 1,
      subheader: 1,
      notes: 1,
      shoot_details: 1,
      proposal_details: 1
    ]

  @impl true
  def mount(%{"id" => job_id}, _session, socket) do
    socket
    |> assign_stripe_status()
    |> assign(include_questionnaire: true)
    |> assign_job(job_id)
    |> assign_proposal()
    |> ok()
  end

  @impl true
  def handle_event("add-package", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.PackageLive.WizardComponent,
        assigns |> Map.take([:current_user, :job])
      )
      |> noreply()

  @impl true
  def handle_event(
        "edit-package",
        %{},
        %{assigns: assigns} = socket
      ),
      do:
        socket
        |> open_modal(
          PicselloWeb.PackageLive.WizardComponent,
          assigns |> Map.take([:current_user, :job, :package])
        )
        |> noreply()

  @impl true
  def handle_event(
        "finish-proposal",
        %{},
        %{assigns: %{job: job}} = socket
      ) do
    %{client: %{organization: %{name: organization_name}, name: client_name}} =
      job = Repo.preload(job, client: :organization)

    subject = "Booking proposal from #{organization_name}"
    body = "Hello #{client_name}.\r\n\r\nYou have a booking proposal from #{organization_name}."

    socket
    |> assign(:job, job)
    |> PicselloWeb.ClientMessageComponent.open(%{
      composed_event: :proposal_message_composed,
      body_html: body,
      body_text: body,
      subject: subject
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "manage",
        %{},
        %{assigns: %{job: job}} = socket
      ) do
    actions =
      [%{title: "Send an email", action_event: "open_email_compose"}]
      |> Enum.concat(
        if job.archived_at,
          do: [],
          else: [%{title: "Archive lead", action_event: "confirm_archive_lead"}]
      )

    socket
    |> PicselloWeb.ActionSheetComponent.open(%{
      title: "Manage #{Job.name(job)}",
      actions: actions
    })
    |> noreply()
  end

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
  def handle_info({:action_event, "confirm_archive_lead"}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Get me out of here",
      confirm_event: "archive",
      confirm_label: "Yes, archive the lead",
      icon: "warning-orange",
      title: "Are you sure you want to archive this lead?"
    })
    |> noreply()
  end

  @impl true
  def handle_info(
        {:proposal_message_composed, message_changeset},
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
      {:ok, %{message: message}} ->
        %{client: client} = job = job |> Repo.preload([:client, :job_status], force: true)
        ClientNotifier.deliver_booking_proposal(message, client.email)

        socket
        |> assign_proposal()
        |> assign(:job, job)
        |> PicselloWeb.ConfirmationComponent.open(%{
          title: "Email sent",
          subtitle: "Yay! Your email has been successfully sent"
        })
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to create booking proposal. Please try again.")
        |> noreply()
    end
  end

  @impl true
  def handle_info({:confirm_event, "archive"}, %{assigns: %{job: job}} = socket) do
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
  def handle_info({:stripe_status, status}, socket) do
    socket |> assign(stripe_status: status) |> noreply()
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared

  def next_reminder_on(nil), do: nil
  defdelegate next_reminder_on(proposal), to: Picsello.ProposalReminder

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: payments().status(current_user))
  end

  defp payments, do: Application.get_env(:picsello, :payments)
end
