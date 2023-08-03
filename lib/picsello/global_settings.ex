defmodule Picsello.GlobalSettings do
  @moduledoc false
  alias Picsello.GlobalSettings.GalleryProduct, as: GSGalleryProduct
  alias Picsello.GlobalSettings.PrintProduct, as: GSPrintProduct
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Picsello.{Repo, Category, UserCurrency}
  alias Ecto.Multi
  alias Picsello.Galleries.GalleryProduct
  alias Ecto.Changeset
  import Ecto.Query
  alias Ecto.Changeset

  @whcc_print_category Category.print_category()

  def update_gallery_product(%GSGalleryProduct{} = gs_gallery_product, opts)
      when is_list(opts) do
    attrs = Enum.into(opts, %{})

    Multi.new()
    |> Multi.update(:gs_gallery_product, GSGalleryProduct.changeset(gs_gallery_product, attrs))
    |> Multi.update_all(
      :gallery_products,
      fn %{gs_gallery_product: gs_gallery_product} ->
        from(gallery_product in GalleryProduct,
          join: gallery in assoc(gallery_product, :gallery),
          join: job in assoc(gallery, :job),
          join: client in assoc(job, :client),
          where: fragment("? ->> 'products' = 'true'", gallery.use_global),
          where: client.organization_id == ^gs_gallery_product.organization_id,
          where: gallery_product.category_id == ^gs_gallery_product.category_id,
          update: [set: ^opts]
        )
      end,
      []
    )
    |> Repo.transaction()
  end

  def update_gallery_product(%GSGalleryProduct{} = gs_gallery_product, %{} = attrs) do
    gs_gallery_product
    |> GSGalleryProduct.changeset(attrs)
    |> Repo.update()
  end

  def list_gallery_products(organization_id) do
    gallery_product_query()
    |> where([gs_gp], gs_gp.organization_id == ^organization_id)
    |> order_by([_, category], category.position)
    |> Repo.all()
  end

  def gallery_product(id) do
    gallery_product_query()
    |> where([gs_gp], gs_gp.id == ^id)
    |> Repo.one()
  end

  defp gallery_product_query() do
    GSGalleryProduct
    |> join(:inner, [gs_gp], category in assoc(gs_gp, :category))
    |> join(:left, [_, category], product in assoc(category, :products))
    |> where([_, _, product], is_nil(product.deleted_at))
    |> preload([gs_gp, category, product],
      category: {category, [products: product, gs_gallery_products: gs_gp]}
    )
  end

  def gallery_products_params() do
    categories = Category.all_query() |> where([c], not c.hidden) |> Repo.all()

    categories
    |> Enum.find(%{}, &(&1.whcc_id == @whcc_print_category))
    |> Map.get(:products, [])
    |> Repo.preload(:category)
    |> Enum.map(fn product ->
      {categories, selections} = Picsello.Product.selections_with_prices(product)

      selections
      |> build_print_products(categories)
      |> then(&%{product_id: product.id, sizes: &1})
    end)
    |> then(fn print_category ->
      Enum.map(
        categories,
        &%{
          category_id: &1.id,
          markup: &1.default_markup,
          global_settings_print_products: print_products(&1.whcc_id, print_category)
        }
      )
    end)
  end

  def size([total_cost, print_cost, _, size, type], ["size", _]),
    do: size(total_cost, print_cost, size, type)

  def size([total_cost, print_cost, _, type, size], [_, "size"]),
    do: size(total_cost, print_cost, size, type)

  def size([total_cost, print_cost, _, type, _, size, _, _], [_, _, "size", _, _]),
    do: size(total_cost, print_cost, size, type)

  def size([total_cost, print_cost, _, _mounting, type, size], [_, _, "size"]),
    do: size(total_cost, print_cost, size, type)

  def size(final_cost, base_cost, size, type),
    do: %{final_cost: to_decimal(final_cost), base_cost: base_cost, size: size, type: type}

  def to_decimal(%Money{amount: amount, currency: :USD}),
    do: Decimal.round(to_string(amount / 100), 2)

  @fine_art_prints ~w(torchon photo_rag_metallic)
  def build_print_products(selections, categories) do
    torchon = hd(@fine_art_prints)

    Enum.reduce(selections, [], fn selection, acc ->
      %{type: type} = p_product = size(selection, categories)

      acc ++
        case String.contains?(type, torchon) do
          true -> Enum.map(@fine_art_prints, &Map.put(p_product, :type, &1))
          false -> [p_product]
        end
    end)
  end

  defp print_products(@whcc_print_category, print_category), do: print_category
  defp print_products(_whcc_print_categroy, _print_category), do: []

  def list_print_products(gs_gallery_product_id) do
    GSPrintProduct
    |> join(:inner, [gs_pp], product in assoc(gs_pp, :product))
    |> where([gs_pp], gs_pp.global_settings_gallery_product_id == ^gs_gallery_product_id)
    |> where([_, product], is_nil(product.deleted_at))
    |> Repo.all()
  end

  def update_print_product!(%GSPrintProduct{} = gs_print_product, %{} = attrs) do
    gs_print_product
    |> GSPrintProduct.changeset(attrs)
    |> Repo.update!()
  end

  def get(organization_id), do: Repo.get_by(GSGallery, organization_id: organization_id)

  alias Ecto.Changeset

  def get_or_add!(%{
        organization_id: organization_id,
        currency: currency,
        exchange_rate: rate
      }) do
    case get(organization_id) do
      nil ->
        each_price = GSGallery.default_each_price()
        buy_all_price = GSGallery.default_buy_all_price()

        %GSGallery{}
        |> Changeset.change(
          Map.merge(
            %{organization_id: organization_id},
            build_digital_prices(each_price, buy_all_price, currency, rate)
          )
        )
        |> Repo.insert!()

      gs_gallery ->
        gs_gallery
    end
  end

  def save(%GSGallery{} = gs, attrs), do: Changeset.change(gs, attrs) |> save()
  def save(%Changeset{} = changeset), do: Repo.insert_or_update(changeset)

  def delete_watermark(%GSGallery{} = gs_gallery) do
    save(gs_gallery, Enum.into(GSGallery.watermark_fields(), %{}, &{&1, nil}))
  end

  defp build_digital_prices(each_price, buy_all_price, currency, rate) do
    %{
      download_each_price: Money.new(each_price.amount, currency) |> Money.multiply(rate),
      buy_all_price: Money.new(buy_all_price.amount, currency) |> Money.multiply(rate)
    }
  end

  def update_currency(
        user_currency,
        %{currency: currency, exchange_rate: rate} = attrs
      ) do
    Multi.new()
    |> Multi.update(:update_user_currency, UserCurrency.currency_changeset(user_currency, attrs))
    |> Multi.update(:update_global_settings, fn _ ->
      %{buy_all_price: buy_all_price, download_each_price: download_each_price} =
        gs_gallery = get_or_add!(user_currency)

      GSGallery.price_changeset(
        gs_gallery,
        build_digital_prices(download_each_price, buy_all_price, currency, rate)
      )
    end)
    |> Repo.transaction()
  end
end
