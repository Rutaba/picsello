defmodule Picsello.Profiles do
  @moduledoc "context module for public photographer profile"
  import Ecto.Query, warn: false
  alias Picsello.Repo
  alias Picsello.Organization

  def find_organization_by(slug: slug) do
    from(
      o in Organization,
      where: o.slug == ^slug,
      preload: [:user]
    )
    |> Repo.one!()
  end
end
