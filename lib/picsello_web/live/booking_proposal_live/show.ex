defmodule PicselloWeb.BookingProposalLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  require Logger
  alias Picsello.{Repo, BookingProposal, Job, PaymentSchedules}

  import PicselloWeb.Live.Profile.Shared,
    only: [
      photographer_logo: 1
    ]

  @max_age 60 * 60 * 24 * 365 * 10

  @pages ~w(details contract questionnaire invoice)

  @impl true
  def mount(%{"token" => token} = params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_proposal(token)
    |> maybe_confetti(params)
    |> ok()
  end

  @impl true
  def handle_params(_params, _uri, socket), do: socket |> noreply()

  @impl true
  def handle_event("open-compose", %{}, socket), do: open_compose(socket)

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
  def handle_info({:update, %{proposal: proposal}}, socket),
    do: socket |> assign(proposal: proposal) |> noreply()

  @impl true
  def handle_info({:update, %{answer: answer}}, %{assigns: %{proposal: proposal}} = socket),
    do: socket |> assign(answer: answer, proposal: %{proposal | answer: answer}) |> noreply()

  @impl true
  def handle_info(
        {:confetti, stripe_session_id},
        %{assigns: %{organization: organization, job: job}} = socket
      ) do
    socket =
      with {:ok, session} <-
             payments().retrieve_session(stripe_session_id,
               connect_account: organization.stripe_account_id
             ),
           {:ok, _} <- Picsello.Payments.handle_payment(session) do
        socket
      else
        e ->
          Logger.warning("no match when retrieving stripe session: #{inspect(e)}")
          socket
      end

    socket
    |> assign(job: job |> Repo.preload(:payment_schedules, force: true))
    |> show_confetti_banner()
    # clear the success param
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
      |> Ecto.Changeset.change(job_id: job_id, outbound: false)
      |> Ecto.Changeset.apply_changes()
      |> Repo.insert()
      |> case do
        {:ok, _} ->
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
      cond do
        PaymentSchedules.remainder_paid?(job) ->
          {"Paid in full. Thank you!", "Now it’s time to make some memories."}

        PaymentSchedules.deposit_paid?(job) ->
          {"Thank you! Your #{ngettext("session is", "sessions are", Enum.count(shoots))} now booked.",
           "We are so excited to be working with you, thank you for your business. See you soon."}

        true ->
          {"Thank you!", "We are so excited to be working with you, thank you for your business."}
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
             job: [:client, :payment_schedules, :shoots, package: [organization: :user]]
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
    else
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

  defp invoice_disabled?(%BookingProposal{accepted_at: accepted_at, signed_at: signed_at}) do
    is_nil(accepted_at) || is_nil(signed_at)
  end

  defp open_compose(%{assigns: %{organization: %{name: organization_name}, job: job}} = socket),
    do:
      socket
      |> PicselloWeb.ClientMessageComponent.open(%{
        modal_title: "Contact #{organization_name}",
        show_client_email: false,
        show_subject: false,
        subject: "#{Job.name(job)} proposal",
        presets: [],
        send_button: "Send"
      })
      |> noreply()

  defp payments(), do: Application.get_env(:picsello, :payments)
end
