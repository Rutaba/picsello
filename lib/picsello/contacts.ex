defmodule Picsello.Contacts do
  @moduledoc "context module for contacts"
  import Ecto.Query, only: [from: 2]
  alias Picsello.{Repo, Client}

  def find_all_by(user: user) do
    from(c in Client,
      where: c.organization_id == ^user.organization_id,
      order_by: [asc: c.name, asc: c.email]
    )
    |> Repo.all()
  end
end
