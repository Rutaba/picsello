defmodule PicselloWeb.BookingProposalLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view_client
  alias Picsello.{Repo, BookingProposal, Job}
  require Logger

  @max_age 60 * 60 * 24 * 365 * 10

  @impl true
  def mount(%{"token" => token}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_proposal(token)
    |> ok()
  end

  @impl true
  def handle_event("open-proposal", %{}, %{assigns: assigns} = socket) do
    socket
    |> open_modal(
      PicselloWeb.BookingProposalLive.ProposalComponent,
      assigns
      |> Map.take([:job, :client, :shoots, :package, :proposal, :organization, :photographer])
    )
    |> noreply()
  end

  @impl true
  def handle_event("open-contract", %{}, %{assigns: assigns} = socket) do
    socket
    |> open_modal(
      PicselloWeb.BookingProposalLive.ContractComponent,
      assigns
      |> Map.take([:job, :proposal, :organization])
    )
    |> noreply()
  end

  @impl true
  def handle_event("open-questionnaire", %{}, %{assigns: assigns} = socket) do
    socket
    |> open_modal(
      PicselloWeb.BookingProposalLive.QuestionnaireComponent,
      assigns
      |> Map.take([:job, :proposal, :organization])
    )
    |> noreply()
  end

  @impl true
  def handle_event("redirect-stripe", %{}, socket) do
    %{
      assigns: %{
        package: package,
        proposal: proposal,
        job: job,
        token: token
      }
    } = socket

    redirect_url = Routes.booking_proposal_url(socket, :show, token)

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
           success_url: redirect_url,
           cancel_url: redirect_url
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

  defp assign_proposal(socket, token) do
    case Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: @max_age) do
      {:ok, proposal_id} ->
        proposal =
          Repo.get!(BookingProposal, proposal_id)
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
end
