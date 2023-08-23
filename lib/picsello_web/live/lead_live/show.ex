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
    Contracts,
    Messages
  }

  alias PicselloWeb.JobLive

  import PicselloWeb.Live.Shared, only: [update_package_questionnaire: 1]
  import PicselloWeb.Shared.EditNameComponent, only: [edit_name_input: 1]

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
      validate_payment_schedule: 1,
      error: 1
    ]

  @impl true
  def mount(%{"id" => job_id} = assigns, _session, socket) do
    socket
    |> assign_stripe_status()
    |> assign(:edit_name, false)
    |> assign(include_questionnaire: true)
    |> assign(:type, %{singular: "lead", plural: "leads"})
    |> assign(:request_from, assigns["request_from"])
    |> assign_job(job_id)
    |> assign(:request_from, assigns["request_from"])
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
      <button id="finish-proposal" title="send proposal" class="w-full md:w-auto btn-primary intro-finish-proposal" phx-click="finish-proposal" disabled={@disabled_message}>Send proposal</button>
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
          job =
            job
            |> Repo.preload([:client, :job_status, package: [:contract, :questionnaire_template]],
              force: true
            )

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
        assigns |> Map.take([:current_user, :job, :currency])
      )
      |> assign_disabled_copy_link()
      |> noreply()

  @impl true
  def handle_event("edit-package", %{}, %{assigns: %{proposal: proposal} = assigns} = socket) do
    if is_nil(proposal) || is_nil(proposal.signed_at) do
      socket
      |> PicselloWeb.ConfirmationComponent.open(%{
        confirm_event: "edit_package",
        confirm_label: "Yes, edit package details",
        subtitle:
          "Your proposal has already been created for the client-if you edit the package details, the proposal will update to reflect the changes you make.
          \nPRO TIP: Remember to communicate with your client on the changes!
          ",
        title: "Edit Package details?",
        icon: "warning-orange",
        payload: %{assigns: assigns}
      })
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
          Logger.warning("No booking proposal email preset for #{job.type}")
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
      subject: subject,
      client: Job.client(job)
    })
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

  def handle_event("confirm_unarchive_lead", %{}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Get me out of here",
      confirm_event: "unarchive-lead",
      confirm_label: "Yes, unarchive the lead",
      icon: "warning-orange",
      title: "Are you sure you want to unarchive this lead?"
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
  def handle_event(
        "edit-questionnaire",
        %{},
        socket
      ) do
    socket
    |> update_package_questionnaire()
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
    |> put_flash(:success, "Job updated successfully")
    |> noreply()
  end

  @impl true
  def handle_info(
        {:proposal_message_composed, message_changeset, recipients},
        %{assigns: %{current_user: current_user, job: job}} = socket
      ) do
    socket
    |> upsert_booking_proposal(true)
    |> Ecto.Multi.merge(fn _ ->
      Messages.add_message_to_job(message_changeset, job, recipients, current_user)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{client_message: message, client_message_recipients: _}} ->
        job =
          job
          |> Repo.preload([:client, :job_status, package: [:contract, :questionnaire_template]],
            force: true
          )

        ClientNotifier.deliver_booking_proposal(message, recipients)

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

  def handle_info({:confirm_event, "edit_package"}, %{assigns: assigns} = socket) do
    socket
    |> open_modal(
      PicselloWeb.PackageLive.WizardComponent,
      assigns |> Map.take([:current_user, :job, :package, :currency])
    )
    |> assign_disabled_copy_link()
    |> noreply()
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
  defdelegate handle_info(message, socket), to: JobLive.Shared

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
