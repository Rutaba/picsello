defmodule Picsello.GlobalGallerySettings do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Organization

  schema "global_gallery_settings" do
    field(:expiration_days, :integer)
    belongs_to(:organization, Organization)
    timestamps()
  end

  def expiration_changeset(global_gallery_settings, attrs) do
    global_gallery_settings
    |> cast(attrs, [:expiration_days])
  end
end
