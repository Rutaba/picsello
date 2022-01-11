defmodule Picsello.Payments do
  alias Picsello.{Notifiers.UserNotifier, BookingProposal, Repo}
  alias PicselloWeb.Router.Helpers, as: Routes
  @moduledoc "behavior of (stripe) payout processor"

  @callback link(%Picsello.Organization{}, keyword(binary())) :: {:ok, binary()}
  @callback link(%Picsello.Accounts.User{}, keyword(binary())) :: {:ok, binary()}
  @callback login_link(%Picsello.Accounts.User{}, keyword(binary())) :: {:ok, binary()}
  @callback login_link(%Picsello.Organization{}, keyword(binary())) :: {:ok, binary()}
  @callback status(%Picsello.Organization{}) ::
              {:ok, :none | :processing | :charges_enabled | :details_submitted}
  @callback status(%Picsello.Accounts.User{}) ::
              {:ok, :none | :processing | :charges_enabled | :details_submitted}

  @callback customer_id(%Picsello.Client{}) :: {:ok, binary()}
  @callback checkout_link(%Picsello.BookingProposal{}, list(map()), keyword(binary())) ::
              {:ok, binary()}
  @callback checkout_link(%Picsello.Cart.Order{}, keyword(binary())) ::
              {:ok, %{link: binary(), line_items: [map()]}}
  @callback construct_event(String.t(), String.t(), String.t()) ::
              {:ok, Stripe.Event.t()} | {:error, any}

  @callback retrieve_session(String.t(), keyword(binary())) ::
              {:ok, Stripe.Session.t()} | {:error, Stripe.Error.t()}

  def handle_payment(%Stripe.Session{
        client_reference_id: "proposal_" <> proposal_id,
        metadata: %{"paying_for" => "remainder"}
      }),
      do:
        with(
          {proposal_id, _} <- Integer.parse(proposal_id),
          do:
            %BookingProposal{id: proposal_id}
            |> BookingProposal.remainder_paid_changeset()
            |> Repo.update(returning: true)
        )

  def handle_payment(%Stripe.Session{
        client_reference_id: "proposal_" <> proposal_id,
        metadata: %{"paying_for" => "deposit"}
      }) do
    with %BookingProposal{} = proposal <- Repo.get(BookingProposal, proposal_id),
         {:ok, proposal} = update_result <-
           proposal
           |> BookingProposal.deposit_paid_changeset()
           |> Repo.update() do
      url = Routes.job_url(PicselloWeb.Endpoint, :jobs)
      UserNotifier.deliver_lead_converted_to_job(proposal, url)

      update_result
    else
      {:error, _} = error -> error
      error -> {:error, error}
    end
  end
end
