defmodule Picsello.Accounts.User.Promotions do
  @moduledoc "context module for photographer promotions that Picsello is running"

  use Ecto.Schema

  import Ecto.Changeset

  alias Picsello.{
    Accounts.User,
    Repo
  }

  import Ecto.Query

  schema "user_promotions" do
    field(:state, Ecto.Enum, values: [:purchased, :dismissed])
    field(:slug, :string)
    field(:name, :string)

    belongs_to(:user, User)

    timestamps()
  end

  def changeset(user_promotions \\ %__MODULE__{}) do
    user_promotions
    |> cast(%{}, [:user_id])
  end

  def get_user_promotion_by_slug(%{id: id}, slug) do
    from(up in __MODULE__,
      where: up.slug == ^slug,
      where: up.user_id == ^id,
      select: up
    )
    |> Repo.one()
  end

  def insert_or_update_promotion(current_user, attrs \\ %{}) do
    user_promotion = get_user_promotion_by_slug(current_user, attrs.slug)

    if is_nil(user_promotion) do
      %__MODULE__{}
      |> change(attrs)
      |> put_assoc(:user, current_user)
      |> Repo.insert()
    else
      user_promotion
      |> change(attrs)
      |> Repo.update()
    end
  end

  def dismiss_promotion(user_promotion) do
    user_promotion
    |> change(state: :dismissed)
    |> Repo.update()
  end
end
