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
    Contracts
  }

  import PicselloWeb.JobLive.Shared,
    only: [
      assign_job: 2,
      assign_proposal: 1,
      assign_disabled_copy_link: 1,
      proposal_disabled_message: 1,
      booking_details_section: 1,
      communications_card: 1,
      history_card: 1,
      package_details_card: 1,
      private_notes_card: 1,
      section: 1,
      shoot_details_section: 1,
      title_header: 1,
      validate_payment_schedule: 1,
      error: 1
    ]

  @impl true
  def mount(%{"id" => job_id}, _session, socket) do
    socket
    |> assign_stripe_status()
    |> assign(include_questionnaire: true)
    |> assign_job(job_id)
    |> assign(:collapsed_sections, [])
    |> then(fn %{assigns: assigns} = socket ->
      job = Map.get(assigns, :job)

      if(job) do
        payment_schedules = job |> Repo.preload(:payment_schedules) |> Map.get(:payment_schedules)

        socket
        |> assign(payment_schedules: payment_schedules)
        |> validate_payment_schedule()
        |> assign_disabled_copy_link()
      else
        socket
      end
    end)
    |> ok()
  end

  def send_proposal_button(assigns) do
    assigns =
      assigns
      |> assign(:disabled_message, proposal_disabled_message(assigns))
      |> assign_new(:show_message, fn -> true end)
      |> assign_new(:class, fn -> nil end)

    ~H"""
    <div class={"flex flex-col items-center #{@class}"}>
      <button id="finish-proposal" title="finish proposal" class="w-full md:w-auto btn-primary intro-finish-proposal" phx-click="finish-proposal" disabled={!@is_schedule_valid || @disabled_message}>Send proposal</button>
      <%= if @show_message && @disabled_message do %>
        <em class="pt-1 text-xs text-red-sales-300"><%= @disabled_message %></em>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("copy-client-link", _, %{assigns: %{proposal: proposal, job: job}} = socket) do
    if proposal do
      socket
    else
      socket
      |> upsert_booking_proposal()
      |> Repo.transaction()
      |> case do
        {:ok, %{proposal: proposal}} ->
          job = job |> Repo.preload([:client, :job_status, package: :contract], force: true)

          socket
          |> assign(proposal: proposal)
          |> assign(job: job, package: job.package)
          |> push_event("CopyToClipboard", %{"url" => BookingProposal.url(proposal.id)})

        {:error, _} ->
          socket
          |> put_flash(:error, "Failed to fetch booking proposal. Please try again.")
      end
    end
    |> noreply()
  end

  @impl true
  def handle_event("add-package", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.PackageLive.WizardComponent,
        assigns |> Map.take([:current_user, :job])
      )
      |> assign_disabled_copy_link()
      |> noreply()

  @impl true
  def handle_event("edit-package", %{}, %{assigns: %{proposal: proposal} = assigns} = socket) do
    if is_nil(proposal) || is_nil(proposal.accepted_at) do
      socket
      |> open_modal(
        PicselloWeb.PackageLive.WizardComponent,
        assigns |> Map.take([:current_user, :job, :package])
      )
      |> assign_disabled_copy_link()
    else
      socket
      |> put_flash(:error, "Package can't be changed")
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "finish-proposal",
        %{},
        %{assigns: %{job: job, current_user: current_user}} = socket
      ) do
    %{body_template: body_html, subject_template: subject} =
      case Picsello.EmailPresets.for(job, :booking_proposal) do
        [preset | _] ->
          Picsello.EmailPresets.resolve_variables(
            preset,
            {job},
            PicselloWeb.Helpers
          )

        _ ->
          Logger.warn("No booking proposal email preset for #{job.type}")
          %{body_template: "", subject_template: ""}
      end

    socket
    |> assign(:job, job)
    |> PicselloWeb.ClientMessageComponent.open(%{
      composed_event: :proposal_message_composed,
      current_user: current_user,
      enable_size: true,
      enable_image: true,
      presets: [],
      body_html: body_html,
      subject: subject
    })
    |> noreply()
  end

  def handle_event("open_lead_name_change", %{}, %{assigns: %{job: job}} = socket) do
    assigns = %{
      job: job,
      current_user: Map.take(socket.assigns, [:current_user])
    }

    socket
    |> open_modal(
      PicselloWeb.Live.Profile.EditNameSharedComponent,
      Map.put(assigns, :parent_pid, self())
    )
    |> noreply()
  end

  def handle_event("confirm_archive_lead", %{}, socket) do
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

  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

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
  def handle_event("edit-contract", %{}, socket) do
    socket
    |> PicselloWeb.ContractFormComponent.open(
      Map.take(socket.assigns, [:package, :job, :current_user])
    )
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  def handle_info({:update, %{job: job}}, socket) do
    socket
    |> assign(:job, job)
    |> put_flash(:success, "Name updated successfully")
    |> noreply()
  end

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
        %{assigns: %{job: job}} = socket
      ) do
    result =
      socket
      |> upsert_booking_proposal(true)
      |> Ecto.Multi.insert(
        :message,
        Ecto.Changeset.put_change(message_changeset, :job_id, job.id)
      )
      |> Repo.transaction()

    case result do
      {:ok, %{message: message}} ->
        %{client: client} =
          job = job |> Repo.preload([:client, :job_status, package: :contract], force: true)

        ClientNotifier.deliver_booking_proposal(message, client.email)

        socket
        |> assign_proposal()
        |> assign(job: job, package: job.package)
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
    case Picsello.Jobs.archive_lead(job) do
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
    socket
    |> assign(stripe_status: status)
    |> assign_disabled_copy_link()
    |> noreply()
  end

  @impl true
  def handle_info({:contract_saved, contract}, %{assigns: %{package: package}} = socket) do
    socket
    |> assign(package: %{package | contract: contract})
    |> put_flash(:success, "New contract added successfully")
    |> close_modal()
    |> assign_disabled_copy_link()
    |> noreply()
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared

  def next_reminder_on(nil), do: nil

  def next_reminder_on(%{sent_to_client: false}), do: nil

  defdelegate next_reminder_on(proposal), to: Picsello.ProposalReminder

  defp upsert_booking_proposal(
         %{
           assigns: %{
             proposal: proposal,
             job: job,
             package: package,
             include_questionnaire: include_questionnaire
           }
         },
         sent_to_client \\ false
       ) do
    questionnaire_id =
      if include_questionnaire, do: job |> Questionnaire.for_job() |> Repo.one() |> Map.get(:id)

    changeset =
      BookingProposal.create_changeset(%{
        job_id: job.id,
        questionnaire_id: questionnaire_id,
        sent_to_client: sent_to_client
      })

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :proposal,
      if(proposal, do: Ecto.Changeset.put_change(changeset, :id, proposal.id), else: changeset),
      on_conflict: {:replace, [:questionnaire_id, :sent_to_client]},
      conflict_target: :id
    )
    |> Ecto.Multi.merge(fn _ ->
      Contracts.maybe_add_default_contract_to_package_multi(package)
    end)
  end

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: Payments.status(current_user))
  end
end
