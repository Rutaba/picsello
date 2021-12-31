defmodule Picsello.CategoryTemplate do
  @moduledoc false
  use Ecto.Schema
  require Logger
  import Ecto.{Changeset, Query}
  alias Picsello.Repo
  alias Picsello.Category
  alias Picsello.Galleries.GalleryProduct
  alias __MODULE__

  schema "category_templates" do
    field :corners, {:array, :integer}
    field :name, :string
    field :title, :string
    field :price, Money.Ecto.Amount.Type
    belongs_to(:category, Category)

    timestamps()
  end

  def all, do: Repo.all(CategoryTemplate)

  def all_with_gallery_products do
    Repo.all(
      from ct in __MODULE__,
        join: gallery_products in GalleryProduct,
        on: ct.id == gallery_products.category_template_id,
        select: %{
          name: ct.name,
          corners: ct.corners,
          cid: ct.id,
          title: ct.title,
          price: ct.price,
          gid: gallery_products.id
        }
    )
  end

  @doc false
  def changeset(category_template, attrs) do
    category_template
    |> cast(attrs, [:name, :corners, :title])
    |> validate_required([:name, :corners, :title])
  end

  @frames [
    %{
      name: "card_blank.png",
      category_name: "Loose Prints",
      title: "Prints",
      price: Money.new(80_75),
      corners: [0, 0, 0, 0, 0, 0, 0, 0]
    },
    %{
      name: "album_transparency.png",
      category_name: "Albums",
      title: "Custom Albums",
      price: Money.new(1_5),
      corners: [800, 715, 1720, 715, 800, 1620, 1720, 1620]
    },
    %{
      name: "card_envelope.png",
      category_name: "Press Printed Cards",
      title: "Greeting Cards",
      price: Money.new(30),
      corners: [1650, 610, 3100, 610, 1650, 2620, 3100, 2620]
    },
    %{
      name: "frame_transparency.png",
      category_name: "Wall Displays",
      title: "Framed Prints",
      price: Money.new(5),
      corners: [550, 550, 2110, 550, 550, 1600, 2110, 1600]
    }
  ]

  def seed_templates() do
    if Repo.aggregate(CategoryTemplate, :count) == 0 do
      Enum.each(@frames, fn row ->
        result = Repo.get_by(Category, %{name: row.category_name})
        insert_template(result, row)
      end)
    end
  end

  defp insert_template(%{id: category_id}, row) do
    Repo.insert!(%CategoryTemplate{
      name: row.name,
      title: row.title,
      corners: row.corners,
      category_id: category_id
    })
  end

  defp insert_template(_r, _row) do
    Logger.error("No match any categories for template please start Picsello.WHCC.sync()")
  end
end
