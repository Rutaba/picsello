defmodule PicselloWeb.BookingProposalLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view_client
  alias Picsello.{Repo, BookingProposal, Job}
  require Logger

  @max_age 60 * 60 * 24 * 7

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
  def handle_event("redirect-stripe", %{}, socket) do
    %{
      assigns: %{
        package: package,
        proposal: proposal,
        job: job,
        token: token,
        organization: organization,
        client: client
      }
    } = socket

    redirect_url = Routes.booking_proposal_url(socket, :show, token)

    customer_id = payments().customer_id(client)

    stripe_params = %{
      client_reference_id: "proposal_#{proposal.id}",
      cancel_url: redirect_url,
      success_url: redirect_url,
      payment_method_types: ["card"],
      customer: customer_id,
      mode: "payment",
      line_items: [
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
    }

    case Stripe.Session.create(stripe_params, connect_account: organization.stripe_account_id) do
      {:ok, session} ->
        socket
        |> redirect(external: session.url)
        |> noreply()

      {:error, error} ->
        Logger.error(error)
        socket |> put_flash(:error, "Couldn't redirect to stripe. Please try again") |> noreply()
    end
  end

  @impl true
  def handle_info({:update, %{proposal: proposal}}, socket),
    do: socket |> assign(proposal: proposal) |> noreply()

  defp assign_proposal(socket, token) do
    case Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: @max_age) do
      {:ok, proposal_id} ->
        proposal =
          Repo.get!(BookingProposal, proposal_id)
          |> Repo.preload(job: [:client, :shoots, package: [organization: :user]])

        %{
          job:
            %{
              client: client,
              shoots: shoots,
              package: %{organization: %{user: photographer} = organization} = package
            } = job
        } = proposal

        socket
        |> assign(
          token: token,
          proposal: proposal,
          job: job,
          client: client,
          shoots: shoots,
          package: package,
          organization: organization,
          photographer: photographer
        )

      {:error, _} ->
        socket
        |> assign(proposal: nil)
        |> put_flash(:error, "This proposal is not available anymore")
    end
  end

  defp payments, do: Application.get_env(:picsello, :payments)
end
