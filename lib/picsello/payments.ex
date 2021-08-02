defmodule Picsello.Payments do
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
  @callback construct_event(String.t(), String.t(), String.t()) ::
              {:ok, Stripe.Event.t()} | {:error, any}
end
