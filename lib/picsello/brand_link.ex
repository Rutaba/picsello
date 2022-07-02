defmodule Picsello.BrandLink do
  @moduledoc "a public image embedded in the profile json"
  use Ecto.Schema
  import Ecto.Changeset

  schema "brand_links" do
    field :title, :string
    field :link_id, :string
    field :link, :string
    field :active?, :boolean, default: false
    field :use_publicly?, :boolean, default: false
    field :show_on_profile?, :boolean, default: false

    belongs_to :organization, Picsello.Organization
  end

  def create_changeset(%__MODULE__{} = brand_link, attrs) do
    cast(brand_link, attrs, [
      :title,
      :link,
      :link_id,
      :active?,
      :use_publicly?,
      :show_on_profile?,
      :organization_id
    ])
    |> validate_required([:title, :organization_id, :link_id])
    |> validate_change(
      :link,
      &for(e <- Picsello.Profiles.Profile.url_validation_errors(&2), do: {&1, e})
    )
  end

  def update_changeset(%__MODULE__{} = brand_link, attrs) do
    cast(brand_link, attrs, [
      :title,
      :link,
      :link_id,
      :active?,
      :use_publicly?,
      :show_on_profile?
    ])
    |> validate_required([:title, :link, :link_id])
    |> validate_length(:title, max: 50)
    |> validate_change(
      :link,
      &for(e <- Picsello.Profiles.Profile.url_validation_errors(&2), do: {&1, e})
    )
  end

  def brand_link_changeset(brand_link, attrs) do
    cast(brand_link, attrs, [
      :link
    ])
    |> validate_change(
      :link,
      &for(e <- Picsello.Profiles.Profile.url_validation_errors(&2), do: {&1, e})
    )
  end
end
