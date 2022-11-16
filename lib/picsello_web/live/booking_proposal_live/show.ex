defmodule PicselloWeb.BookingProposalLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  require Logger
  alias Picsello.{Repo, BookingProposal, Job, Payments, PaymentSchedules, Messages}
  alias PicselloWeb.BookingProposalLive.ScheduleComponent

  import PicselloWeb.Live.Profile.Shared,
    only: [
      assign_organization: 2,
      photographer_logo: 1,
      profile_footer: 1
    ]

  import PicselloWeb.ClientBookingEventLive.Shared,
    only: [subtitle_display: 1, date_display: 1, address_display: 1]

  @max_age 60 * 60 * 24 * 365 * 10

  @pages ~w(details contract questionnaire invoice)

  @impl true
  def mount(%{"token" => token} = params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_proposal(token)
    |> assign_stripe_status()
    |> maybe_confetti(params)
    |> maybe_set_booking_countdown()
    |> ok()
  end

  @impl true
  def handle_params(_params, _uri, socket), do: socket |> noreply()

  @impl true
  def handle_event("open-compose", %{}, socket), do: open_compose(socket)

  @impl true
  def handle_event(
        "open_schedule_popup",
        _params,
        %{assigns: %{proposal: proposal, job: job}} = socket
      ) do
    socket
    |> open_modal(ScheduleComponent, %{proposal: proposal, job: job})
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-" <> page,
        %{},
        %{assigns: %{read_only: read_only}} = socket
      )
      when page in @pages do
    socket
    |> open_page_modal(page, read_only)
    |> noreply()
  end

  @impl true
  def handle_info({:stripe_status, status}, socket) do
    socket
    |> assign(stripe_status: status)
    |> maybe_display_stripe_error()
    |> noreply()
  end

  @impl true
  def handle_info({:update, %{proposal: proposal}}, socket),
    do: socket |> assign(proposal: proposal) |> noreply()

  @impl true
  def handle_info({:update, %{answer: answer}}, %{assigns: %{proposal: proposal}} = socket),
    do: socket |> assign(answer: answer, proposal: %{proposal | answer: answer}) |> noreply()

  @impl true
  def handle_info({:update_payment_schedules}, %{assigns: %{job: job}} = socket),
    do:
      socket
      |> assign(job: job |> Repo.preload(:payment_schedules, force: true))
      |> show_confetti_banner()
      |> noreply()

  @impl true
  def handle_info({:update_offline_payment_schedules}, %{assigns: %{job: job}} = socket),
    do:
      socket
      |> assign(job: job |> Repo.preload(:payment_schedules, force: true))
      |> PicselloWeb.ConfirmationComponent.open(%{
        title: "Session Booked",
        subtitle: "Your session is booked with an in-person cash or check payment. Thank you!",
        close_label: "Got it",
        icon: nil,
        close_class: "btn-primary"
      })
      |> noreply()

  @impl true
  def handle_info(
        {:confetti, stripe_session_id},
        %{assigns: %{organization: organization, job: job}} = socket
      ) do
    socket =
      with {:ok, session} <-
             Payments.retrieve_session(stripe_session_id,
               connect_account: organization.stripe_account_id
             ),
           {:ok, _} <-
             PaymentSchedules.handle_payment(
               session,
               PicselloWeb.Helpers
             ) do
        socket
      else
        e ->
          Logger.warning("no match when retrieving stripe session: #{inspect(e)}")
          socket
      end

    socket
    |> assign(job: job |> Repo.preload(:payment_schedules, force: true))
    |> show_confetti_banner()
    # clear the session_id param
    |> push_patch(to: stripe_redirect(socket, :path), replace: true)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:message_composed, changeset},
        %{
          assigns: %{
            organization: %{name: organization_name},
            job: %{id: job_id}
          }
        } = socket
      ) do
    flash =
      changeset
      |> Ecto.Changeset.change(job_id: job_id, outbound: false, read_at: nil)
      |> Ecto.Changeset.apply_changes()
      |> Repo.insert()
      |> case do
        {:ok, message} ->
          Messages.notify_inbound_message(message, PicselloWeb.Helpers)

          &PicselloWeb.ConfirmationComponent.open(&1, %{
            title: "Contact #{organization_name}",
            subtitle: "Thank you! Your message has been sent. We’ll be in touch with you soon.",
            icon: nil,
            confirm_label: "Send another",
            confirm_class: "btn-primary",
            confirm_event: "send_another"
          })

        {:error, _} ->
          &(&1 |> close_modal() |> put_flash(:error, "Message not sent."))
      end

    socket |> flash.() |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "send_another"}, socket), do: open_compose(socket)

  @impl true
  def handle_info(:booking_countdown, socket) do
    socket
    |> maybe_expire_booking()
    |> noreply()
  end

  def open_page_modal(%{assigns: %{proposal: proposal}} = socket, page, read_only \\ false)
      when page in @pages do
    Map.get(
      %{
        "questionnaire" => PicselloWeb.BookingProposalLive.QuestionnaireComponent,
        "details" => PicselloWeb.BookingProposalLive.ProposalComponent,
        "contract" => PicselloWeb.BookingProposalLive.ContractComponent,
        "invoice" => PicselloWeb.BookingProposalLive.InvoiceComponent
      },
      page
    )
    |> apply(:open_modal_from_proposal, [socket, proposal, read_only])
  end

  defp show_confetti_banner(%{assigns: %{job: %{shoots: shoots} = job}} = socket) do
    {title, subtitle} =
      if !PaymentSchedules.all_paid?(job) || PaymentSchedules.free?(job) do
        {"Thank you! Your #{ngettext("session is", "sessions are", Enum.count(shoots))} now booked.",
         "We are so excited to be working with you, thank you for your business. See you soon."}
      else
        {"Paid in full. Thank you!", "Now it’s time to make some memories."}
      end

    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      title: title,
      subtitle: subtitle,
      close_label: "Got it",
      icon: nil,
      close_class: "btn-primary"
    })
  end

  defp assign_proposal(%{assigns: %{current_user: current_user}} = socket, token) do
    with {:ok, proposal_id} <-
           Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: @max_age),
         %{job: %{archived_at: nil}} = proposal <-
           BookingProposal
           |> Repo.get!(proposal_id)
           |> Repo.preload([
             :answer,
             job: [
               :client,
               :job_status,
               :payment_schedules,
               :booking_event,
               :shoots,
               package: [organization: [:user, :brand_links]]
             ]
           ]) do
      %{
        answer: answer,
        job:
          %{
            package: %{organization: %{user: photographer} = organization} = package
          } = job
      } = proposal

      socket
      |> assign(
        answer: answer,
        job: job,
        organization: organization,
        package: package,
        photographer: photographer,
        proposal: proposal,
        page_title:
          [organization.name, job.type |> Phoenix.Naming.humanize()]
          |> Enum.join(" - "),
        read_only: photographer == current_user,
        token: token
      )
      |> assign_organization(organization)
    else
      %{
        job: %{
          booking_event: %Picsello.BookingEvent{} = booking_event,
          archived_at: %DateTime{},
          package: package
        }
      } ->
        socket
        |> assign(proposal: nil)
        |> redirect_to_expired_booking_event(package.organization, booking_event)

      _ ->
        socket
        |> assign(proposal: nil)
        |> put_flash(:error, "This proposal is not available anymore")
    end
  end

  defp stripe_redirect(%{assigns: %{token: token}} = socket, suffix, params \\ []),
    do: apply(Routes, :"booking_proposal_#{suffix}", [socket, :show, token, params])

  defp maybe_confetti(socket, %{
         "session_id" => "" <> session_id
       }) do
    if connected?(socket),
      do: send(self(), {:confetti, session_id})

    socket
  end

  defp maybe_confetti(socket, %{}), do: socket

  defp invoice_disabled?(
         %BookingProposal{accepted_at: accepted_at, signed_at: signed_at, job: job},
         :charges_enabled
       ) do
    !Job.imported?(job) && (is_nil(accepted_at) || is_nil(signed_at))
  end

  defp invoice_disabled?(_proposal, _stripe_status), do: true

  defp open_compose(%{assigns: %{organization: %{name: organization_name}, job: job}} = socket),
    do:
      socket
      |> PicselloWeb.ClientMessageComponent.open(%{
        modal_title: "Contact #{organization_name}",
        show_client_email: false,
        show_subject: false,
        subject: "#{Job.name(job)} proposal",
        presets: [],
        send_button: "Send",
        client: Job.client(job)
      })
      |> noreply()

  defp assign_stripe_status(%{assigns: %{photographer: photographer}} = socket) do
    socket
    |> assign(stripe_status: Payments.status(photographer))
    |> maybe_display_stripe_error()
  end

  defp assign_stripe_status(socket), do: socket

  defp maybe_display_stripe_error(%{assigns: %{stripe_status: stripe_status}} = socket) do
    if Enum.member?([:charges_enabled, :loading], stripe_status) do
      socket
    else
      socket
      |> put_flash(:error, "Payment is not enabled yet. Please contact your photographer.")
    end
  end

  defp formatted_date(%Job{shoots: [shoot | _]}, photographer) do
    strftime(photographer.time_zone, shoot.starts_at, "%A, %B %-d @ %-I:%M %P")
  end

  defp maybe_set_booking_countdown(%{assigns: %{job: job}} = socket) do
    if show_booking_countdown?(job) && connected?(socket),
      do: Process.send_after(self(), :booking_countdown, 1000)

    socket
    |> assign_booking_countdown()
  end

  defp maybe_set_booking_countdown(socket), do: socket

  defp assign_booking_countdown(%{assigns: %{job: job}} = socket) do
    reservation_seconds = Application.get_env(:picsello, :booking_reservation_seconds)

    countdown =
      job.inserted_at |> DateTime.add(reservation_seconds) |> DateTime.diff(DateTime.utc_now())

    socket
    |> assign(booking_countdown: countdown)
  end

  def show_booking_countdown?(job),
    do:
      job.booking_event && !PaymentSchedules.all_paid?(job) &&
        !PaymentSchedules.is_with_cash?(job)

  defp maybe_expire_booking(
         %{assigns: %{booking_countdown: booking_countdown, job: job, organization: organization}} =
           socket
       ) do
    if booking_countdown <= 0 do
      case Picsello.BookingEvents.expire_booking(job) do
        {:ok, _} ->
          socket
          |> redirect_to_expired_booking_event(organization, job.booking_event)

        _ ->
          socket |> put_flash(:error, "Unexpected error")
      end
    else
      socket
      |> maybe_set_booking_countdown()
    end
  end

  def redirect_to_expired_booking_event(socket, organization, booking_event) do
    socket
    |> push_redirect(
      to:
        Routes.client_booking_event_path(
          socket,
          :show,
          organization.slug,
          booking_event.id,
          booking_expired: true
        )
    )
  end

  defp pending_amount_details(job),
    do:
      if(PaymentSchedules.owed_amount(job) > PaymentSchedules.paid_amount(job),
        do: "To-Do",
        else:
          "Next payment due: #{PaymentSchedules.remainder_due_on(job) |> format_date_via_type("MM/DD/YY")}"
      )
end
