defmodule Picsello.Payments do
  @moduledoc "behavior of (stripe) payout processor"

  @callback link(%Picsello.Accounts.User{}, keyword(binary())) :: {:ok, binary()}
  @callback status(%Picsello.Accounts.User{}) ::
              {:ok, :none | :processing | :charges_enabled | :details_submitted}
end
