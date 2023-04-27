defmodule Picsello.GlobalSettings do
  @moduledoc false
  alias Picsello.GlobalSettings.GalleryProduct, as: GSGalleryProduct
  alias Picsello.GlobalSettings.PrintProduct, as: GSPrintProduct
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Picsello.{Repo, Category}
  alias Ecto.Multi
  alias Picsello.Galleries.GalleryProduct
  alias Ecto.Changeset
  import Ecto.Query
  alias Ecto.Changeset
  alias Picsello.Galleries
  alias Picsello.Workers.CleanStore

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
    |> preload([gs_gp, category], category: {category, [:products, gs_gallery_products: gs_gp]})
  end

  def gallery_products_params() do
    categories = Category.all_query() |> where([c], not c.hidden) |> Repo.all()

    categories
    |> Enum.find(%{}, &(&1.whcc_id == @whcc_print_category))
    |> Map.get(:products, [])
    |> Enum.map(fn product ->
      product = Picsello.Repo.preload(product, :category)
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
    from(gs_print_product in GSPrintProduct,
      where: gs_print_product.global_settings_gallery_product_id == ^gs_gallery_product_id
    )
    |> Repo.all()
  end

  def update_print_product!(%GSPrintProduct{} = gs_print_product, %{} = attrs) do
    gs_print_product
    |> GSPrintProduct.changeset(attrs)
    |> Repo.update!()
  end

  def get(organization_id), do: Repo.get_by(GSGallery, organization_id: organization_id)

  def get_or_add(organization_id) do
    case get(organization_id) do
      nil ->
        {:ok, gs} = save(%GSGallery{}, %{organization_id: organization_id})
        gs

      gs_gallery ->
        gs_gallery
    end
  end

  def save(%GSGallery{} = gs, attrs), do: Changeset.change(gs, attrs) |> Repo.insert_or_update()
  def save_watermark(gs_gallery, changes) do
    gs_gallery
    |> save_with_galleries_multi(changes, :watermark)
    |> Multi.run(:multiple_watermarks, fn _, %{gs_gallery: gs_gallery, galleries: galleries} ->
      watermark_change = build_watermark_change(gs_gallery)

      Galleries.save_multiple_watermarks(galleries, watermark_change)
    end)
    |> Repo.transaction()
    |> tap(fn
      {:ok, %{galleries: galleries}} ->
        galleries
        |> Repo.preload(:watermark, force: true)
        |> Enum.each(&Galleries.apply_watermark_on_photos(&1))

      x ->
        x
    end)
  end

  @watermark_fields GSGallery.watermark_fields()
  def delete_watermark(%{global_watermark_path: path} = gs_gallery) do
    gs_gallery
    |> save_with_galleries_multi(Enum.into(@watermark_fields, %{}, &{&1, nil}), :watermark)
    |> Multi.run(:delete_watermarks, fn _, %{galleries: galleries} ->
      galleries
      |> Enum.map(& &1.id)
      |> Galleries.delete_and_clear_multiple_watermarks()
    end)
    |> Oban.insert(:delete_preview, CleanStore.new(%{path: path}))
    |> Repo.transaction()
    |> tap(fn
      {:ok, %{galleries: galleries} = records} ->
        galleries
        |> Repo.preload([:package, job: [client: :organization]])
        |> Enum.each(
          &(records
            |> get_in([:delete_watermarks, &1.id, :proofing_photos])
            |> Galleries.apply_watermark_to_photos(&1))
        )

      x ->
        x
    end)
  end

  def update_prices(gs_gallery, opts) do
    gs_gallery
    |> save_with_galleries_multi(build_price(opts), :digita)
    |> Multi.update_all(
      :update_package,
      fn %{galleries: galleries} ->
        galleries
        |> Enum.map(& &1.id)
        |> Picsello.Packages.update_all_query(opts)
      end,
      []
    )
    |> Repo.transaction()
  end

  defp build_price(buy_all: buy_all), do: [buy_all_price: buy_all]
  defp build_price(opts), do: opts

  def update_expired_at(gs_gallery, changes, opts) do
    gs_gallery
    |> save_with_galleries_multi(changes, :expiration)
    |> Multi.run(:update_expired_at, fn _, %{galleries: galleries} ->
      galleries
      |> Enum.map(& &1.id)
      |> Galleries.update_all(opts)

      {:ok, ""}
    end)
    |> Repo.transaction()
  end

  def save_with_galleries_multi(gs_gallery, attrs, setting_type) do
    Multi.new()
    |> Multi.update(:gs_gallery, changeset(gs_gallery, attrs))
    |> Multi.run(:galleries, fn _, %{gs_gallery: %{organization_id: org_id}} ->
      {:ok,
       org_id
       |> Galleries.list_shared_setting_galleries()
       |> Enum.filter(&Map.get(&1.use_global, setting_type))}
    end)
  end

  def changeset(gs \\ nil, attrs), do: Changeset.change(gs || %GSGallery{}, attrs)

  defp build_watermark_change(%{watermark_type: watermark_type} = global_settings) do
    case watermark_type do
      :image ->
        %{
          name: global_settings.watermark_name,
          size: global_settings.watermark_size,
          type: :image
        }

      :text ->
        %{text: global_settings.watermark_text, type: :text}
    end
  end
end
