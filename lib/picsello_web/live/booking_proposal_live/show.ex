defmodule PicselloWeb.BookingProposalLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.{Repo, BookingProposal, Job}

  alias PicselloWeb.BookingProposalLive.{
    ProposalComponent,
    QuestionnaireComponent,
    ContractComponent,
    ConfettiComponent
  }

  require Logger

  @max_age 60 * 60 * 24 * 365 * 10

  @impl true
  def mount(%{"token" => token} = params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_proposal(token)
    |> then(&maybe_confetti(Map.has_key?(params, "success")).(&1))
    |> ok()
  end

  @impl true
  def handle_params(_params, _uri, socket), do: socket |> noreply()

  @impl true
  def handle_event(
        "open-proposal",
        %{},
        %{assigns: %{proposal: proposal, read_only: read_only}} = socket
      ) do
    socket
    |> ProposalComponent.open_modal_from_proposal(proposal, read_only)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-contract",
        %{},
        %{assigns: %{proposal: proposal, read_only: read_only}} = socket
      ) do
    socket
    |> ContractComponent.open_modal_from_proposal(proposal, read_only)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-questionnaire",
        %{},
        %{assigns: %{proposal: proposal, read_only: read_only}} = socket
      ) do
    socket
    |> QuestionnaireComponent.open_modal_from_proposal(proposal, read_only)
    |> noreply()
  end

  @impl true
  def handle_event("redirect-stripe", %{}, socket) do
    %{
      assigns: %{
        package: package,
        proposal: proposal,
        job: job
      }
    } = socket

    line_items = [
      %{
        price_data: %{
          currency: "usd",
          product_data: %{
            name: "#{Job.name(job)} 50% Deposit"
          },
          unit_amount:
            package.price
            |> Money.multiply(0.5)
            |> then(& &1.amount)
        },
        quantity: 1
      }
    ]

    case payments().checkout_link(proposal, line_items,
           success_url: stripe_redirect(socket, :url, success: true),
           cancel_url: stripe_redirect(socket, :url)
         ) do
      {:ok, url} ->
        socket |> redirect(external: url) |> noreply()

      {:error, error} ->
        Logger.error(error)
        socket |> put_flash(:error, "Couldn't redirect to stripe. Please try again") |> noreply()
    end
  end

  @impl true
  def handle_info({:update, %{proposal: proposal}}, socket),
    do: socket |> assign(proposal: proposal) |> noreply()

  @impl true
  def handle_info({:update, %{answer: answer}}, %{assigns: %{proposal: proposal}} = socket),
    do: socket |> assign(answer: answer, proposal: %{proposal | answer: answer}) |> noreply()

  @impl true
  def handle_info(:confetti, socket) do
    socket
    |> ConfettiComponent.open_modal()
    # clear the success param
    |> push_patch(to: stripe_redirect(socket, :path), replace: true)
    |> noreply()
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

  defp payments, do: Application.get_env(:picsello, :payments)

  defp stripe_redirect(%{assigns: %{token: token}} = socket, suffix, params \\ []),
    do: apply(Routes, :"booking_proposal_#{suffix}", [socket, :show, token, params])

  defp maybe_confetti(has_success_param),
    do: fn %{assigns: %{proposal: proposal}} = socket ->
      if connected?(socket) && proposal && BookingProposal.deposit_paid?(proposal) &&
           has_success_param,
         do: send(self(), :confetti)

      socket
    end
end
