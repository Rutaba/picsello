defmodule Picsello.Galleries.CoverPhoto do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :string
    field :aspect_ratio, :float
    field :width, :integer
    field :height, :integer
    field :gallery_id, :integer
  end

  @create_attrs [:id, :aspect_ratio, :width, :height]
  def changeset(struct, attrs, gallery_id) do
    struct
    |> cast(attrs, @create_attrs)
    |> validate_required([:id])
    |> put_change(:gallery_id, gallery_id)
  end
end
