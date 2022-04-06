defmodule PicselloWeb.LeadLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  require Logger

  alias Picsello.{
    Job,
    Repo,
    Payments,
    BookingProposal,
    Notifiers.ClientNotifier,
    Questionnaire,
    PaymentSchedules
  }

  import PicselloWeb.JobLive.Shared,
    only: [
      assign_job: 2,
      assign_proposal: 1,
      subheader: 1,
      notes: 1,
      shoot_details: 1,
      proposal_details: 1,
      overview_card: 1
    ]

  @impl true
  def mount(%{"id" => job_id}, _session, socket) do
    socket
    |> assign_stripe_status()
    |> assign(include_questionnaire: true)
    |> assign_job(job_id)
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
        %{assigns: %{proposal: nil} = assigns} = socket
      ),
      do:
        socket
        |> open_modal(
          PicselloWeb.PackageLive.WizardComponent,
          assigns |> Map.take([:current_user, :job, :package])
        )
        |> noreply()

  @impl true
  def handle_event("edit-package", %{}, socket), do: socket |> noreply()

  @impl true
  def handle_event(
        "finish-proposal",
        %{},
        %{assigns: %{job: job}} = socket
      ) do
    %{body_template: body_html, subject_template: subject} =
      case Repo.get_by(Picsello.EmailPreset, job_type: job.type, job_state: :booking_proposal) do
        nil ->
          Logger.warn("No booking proposal email preset for #{job.type}")
          %{body_template: "", subject_template: ""}

        preset ->
          Picsello.EmailPreset.resolve_variables(
            preset,
            job,
            PicselloWeb.ClientMessageComponent.PresetHelper
          )
      end

    socket
    |> assign(:job, job)
    |> PicselloWeb.ClientMessageComponent.open(%{
      composed_event: :proposal_message_composed,
      presets: [],
      body_html: body_html,
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
  def handle_event(
        "open-questionnaire",
        %{},
        %{assigns: %{job: job, package: package}} = socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.QuestionnaireComponent.open_modal_from_lead(job, package)
    |> noreply()
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

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
      |> Ecto.Multi.insert_all(:payment_schedules, Picsello.PaymentSchedule, fn _ ->
        PaymentSchedules.build_payment_schedules_for_lead(job) |> Map.get(:payments)
      end)
      |> Ecto.Multi.insert(
        :message,
        Ecto.Changeset.put_change(message_changeset, :job_id, job.id)
      )
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
    socket |> assign(stripe_status: Payments.status(current_user))
  end
end
