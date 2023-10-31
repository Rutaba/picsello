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

  @type t :: %__MODULE__{
          state: atom(),
          slug: string(),
          name: string()
        }

  @spec changeset(t()) :: Changeset.t()
  def changeset(user_promotions \\ %__MODULE__{}) do
    user_promotions
    |> cast(%{}, [:user_id])
  end

  def get_user_promotion_by_slug(current_user, slug) do
    from(up in __MODULE__,
      where: up.slug == ^slug,
      where: up.user_id == ^current_user.id,
      select: up
    )
    |> Repo.one()
  end

  def insert_or_update_promotion(current_user, attrs \\ %{}) do
    user_promotion = get_user_promotion_by_slug(current_user, attrs.slug)

    case user_promotion do
      nil ->
        %__MODULE__{}
        |> Ecto.Changeset.change(attrs)
        |> Ecto.Changeset.put_assoc(:user, current_user)
        |> Repo.insert()

      _ ->
        user_promotion
        |> Ecto.Changeset.change(attrs)
        |> Repo.update()
    end
  end

  def dismiss_promotion(user_promotion) do
    user_promotion
    |> Ecto.Changeset.change(state: :dismissed)
    |> Repo.update()
  end
end
