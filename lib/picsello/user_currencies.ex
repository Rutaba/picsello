defmodule Picsello.UserCurrencies do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query
  alias Picsello.{Repo, UserCurrency}

  def get_user_currency(organization_id) do
    from(user_currency in UserCurrency,
      where: user_currency.organization_id == ^organization_id
    )
    |> Repo.one()
  end
end
