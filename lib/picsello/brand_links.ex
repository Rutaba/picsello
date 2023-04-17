defmodule Picsello.BrandLinks do
  @moduledoc "context module for brand_links"

  import Ecto.Query, warn: false

  alias Picsello.{Repo, BrandLink}

  @doc """
  Gets brand link by organization_id and link_id parameter.

  Returns nil if the brand link does not exist.

  ## Examples

      iex> get_brand_link(link_id, organization_id)
      %BrandLink{}

      iex> get_brand_link(link_id, organization_id)
      nil

  """
  @spec get_brand_link(link_id :: integer, organization_id :: integer) :: BrandLink.t() | nil
  def get_brand_link(link_id, organization_id) do
    Repo.get_by(BrandLink, organization_id: organization_id, link_id: link_id)
  end

  @doc """
  Gets brand links by organization id parameter.

  Returns [] if the brand link does not exist.

  ## Examples

      iex> get_brand_link_by_organization_id(organization_id)
      [%BrandLink{}]

      iex> get_brand_link_by_organization_id(organization_id)
      []

  """
  @spec get_brand_link_by_organization_id(organization_id :: integer) :: list(BrandLink)
  def get_brand_link_by_organization_id(organization_id) do
    from(b in BrandLink, where: b.organization_id == ^organization_id, order_by: b.id)
    |> Repo.all()
  end

  def insert_brand_link(brand_link) do
    %BrandLink{}
    |> BrandLink.create_changeset(brand_link)
    |> Repo.insert()
  end

  def upsert_brand_links(brand_links) do
    Repo.insert_all(BrandLink, brand_links,
      on_conflict: {:replace_all_except, [:link_id, :organization_id]},
      conflict_target: :id
    )
    |> case do
      {_, nil} ->
        get_brand_link_by_organization_id(List.first(brand_links) |> Map.get(:organization_id))

      {_, brand_links} ->
        brand_links
    end
  end

  @spec delete_brand_link(brand_link :: BrandLink.t()) ::
          {:ok, BrandLink.t()} | {:error, Ecto.Changeset.t()}
  def delete_brand_link(brand_link), do: brand_link |> Repo.delete()
end
