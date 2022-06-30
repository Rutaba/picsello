defmodule Picsello.BrandLinks do
  @moduledoc "context module for brand_links"

  import Ecto.Query, warn: false

  alias Picsello.{Repo, BrandLink}

  @doc """
  Returns the list of brand links.

  ## Examples

      iex> list_brand_links()
      [%BrandLink{}, ...]

  """
  def list_brand_links do
    Repo.all(BrandLink)
  end

  @doc """
  Gets brand link by organization_id and link_id parameter.

  Returns nil if the brand link does not exist.

  ## Examples

      iex> get_brand_link(link_id, organization_id)
      %BrandLink{}

      iex> get_brand_link(link_id, organization_id)
      nil

  """
  @spec get_brand_link(link_id :: integer, organization_id :: integer) :: %BrandLink{}
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
    from(b in BrandLink, where: b.organization_id == ^organization_id)
    |> Repo.all()
  end

  def insert_brand_link(brand_link) do
    %BrandLink{}
    |> BrandLink.create_changeset(brand_link)
    |> Repo.insert()
  end

  def insert_brand_links(brand_links) do
    case Repo.insert_all(BrandLink, brand_links) do
      {_, nil} ->
        get_brand_link_by_organization_id(List.first(brand_links) |> Map.get(:organization_id))

      {_, brand_links} ->
        brand_links
    end
  end

  @spec upsert_brand_links(brand_links :: list(%{})) :: {non_neg_integer(), nil | list(BrandLink)}
  def upsert_brand_links(brand_links) do
    Repo.insert_all(BrandLink, brand_links,
      on_conflict: {:replace_all_except, [:link_id, :organization_id]},
      conflict_target: :id
    )
  end

  @spec delete_brand_link(brand_link :: %BrandLink{}) ::
          {:ok, %BrandLink{}} | {:error, %Ecto.Changeset{}}
  def delete_brand_link(brand_link), do: brand_link |> Repo.delete()
end
