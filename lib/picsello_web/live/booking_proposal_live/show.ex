defmodule PicselloWeb.BookingProposalLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.{Repo, BookingProposal, Job}

  @max_age 60 * 60 * 24 * 365 * 10

  @pages ~w(details contract questionnaire invoice)

  @impl true
  def mount(%{"token" => token} = params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_proposal(token)
    |> then(&maybe_confetti(Map.get(params, "success")).(&1))
    |> ok()
  end

  @impl true
  def handle_params(_params, _uri, socket), do: socket |> noreply()

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
  def handle_info({:confetti, payment_type}, socket) do
    socket
    |> show_confetti_banner(payment_type)
    # clear the success param
    |> push_patch(to: stripe_redirect(socket, :path), replace: true)
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

  defp show_confetti_banner(%{assigns: %{proposal: proposal}} = socket, :deposit) do
    if BookingProposal.deposit_paid?(proposal) do
      socket
      |> PicselloWeb.ConfirmationComponent.open(%{
        title: "Thank you! Your session is now booked.",
        subtitle:
          "We are so excited to be working with you, thank you for your business. See you soon.",
        close_label: "Whoo hoo!"
      })
    else
      socket
    end
  end

  defp show_confetti_banner(%{assigns: %{proposal: proposal}} = socket, :remainder) do
    if BookingProposal.remainder_paid?(proposal) do
      socket
      |> PicselloWeb.ConfirmationComponent.open(%{
        title: "Thank you! Your session is now paid for.",
        subtitle:
          "We are so excited to be working with you, thank you for your business. See you soon.",
        close_label: "Whoo hoo!"
      })
    else
      socket
    end
  end

  defp assign_proposal(%{assigns: %{current_user: current_user}} = socket, token) do
    with {:ok, proposal_id} <-
           Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: @max_age),
         %{job: %{archived_at: nil}} = proposal <-
           BookingProposal
           |> Repo.get!(proposal_id)
           |> Repo.preload([:answer, job: [:client, :shoots, package: [organization: :user]]]) do
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

  defp maybe_confetti(success_param),
    do: fn socket ->
      if connected?(socket) && not is_nil(success_param),
        do: send(self(), {:confetti, String.to_existing_atom(success_param)})

      socket
    end

  defp invoice_disabled?(%BookingProposal{accepted_at: accepted_at, signed_at: signed_at}) do
    is_nil(accepted_at) || is_nil(signed_at)
  end
end
