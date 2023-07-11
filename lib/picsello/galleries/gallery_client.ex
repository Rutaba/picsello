defmodule Picsello.Galleries.GalleryClient do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.{Galleries.Gallery, Cart.Order}

  schema "gallery_clients" do
    field :email, :string

    belongs_to(:gallery, Gallery)
    has_many(:orders, Order)

    timestamps(type: :utc_datetime)
  end

  def changeset(gallery_client, attrs \\ %{}) do
    gallery_client
    |> cast(attrs, [:email, :gallery_id])
    |> validate_required([:email, :gallery_id])
    |> validate_email_format(:email)
    |> unique_constraint([:email, :gallery_id])
    |> foreign_key_constraint(:gallery_id)
  end

  defp validate_email_format(changeset, email) do
    changeset
    |> validate_format(email, Picsello.Accounts.User.email_regex(), message: "is invalid")
    |> validate_length(email, max: 160)
    |> update_change(:email, &String.downcase/1)
  end
end
