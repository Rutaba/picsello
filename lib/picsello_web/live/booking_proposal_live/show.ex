defmodule PicselloWeb.BookingProposalLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view_client
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
  def handle_event("open-proposal", %{}, socket) do
    socket
    |> open_modal(
      ProposalComponent,
      modal_assigns(socket, [:client, :shoots, :package, :photographer])
    )
    |> noreply()
  end

  @impl true
  def handle_event("open-contract", %{}, socket) do
    socket
    |> open_modal(
      ContractComponent,
      modal_assigns(socket)
    )
    |> noreply()
  end

  @impl true
  def handle_event("open-questionnaire", %{}, socket) do
    socket
    |> open_modal(
      QuestionnaireComponent,
      modal_assigns(socket)
    )
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
  def handle_info({:update, %{answer: answer}}, socket),
    do: socket |> assign(answer: answer) |> noreply()

  @impl true
  def handle_info(:confetti, socket) do
    socket
    |> ConfettiComponent.open_modal()
    # clear the success param
    |> push_patch(to: stripe_redirect(socket, :path), replace: true)
    |> noreply()
  end

  defp assign_proposal(%{assigns: %{current_user: current_user}} = socket, token) do
    case Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: @max_age) do
      {:ok, proposal_id} ->
        proposal =
          BookingProposal
          |> Repo.get!(proposal_id)
          |> Repo.preload([:answer, job: [:client, :shoots, package: [organization: :user]]])

        %{
          answer: answer,
          job:
            %{
              client: client,
              shoots: shoots,
              package: %{organization: %{user: photographer} = organization} = package
            } = job
        } = proposal

        socket
        |> assign(
          answer: answer,
          client: client,
          job: job,
          organization: organization,
          package: package,
          photographer: photographer,
          proposal: proposal,
          read_only: photographer == current_user,
          shoots: shoots,
          token: token
        )

      {:error, _} ->
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
      if connected?(socket) && BookingProposal.deposit_paid?(proposal) && has_success_param,
        do: send(self(), :confetti)

      socket
    end

  defp modal_assigns(%{assigns: assigns}, extra \\ []),
    do:
      assigns
      |> Map.take([:job, :proposal, :organization, :read_only] ++ extra)
end
