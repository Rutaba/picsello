defmodule Mix.Tasks.UpdatePrintProducts do
  @moduledoc false

  use Mix.Task

  import Ecto.Query
  alias Ecto.Multi
  alias Picsello.{GlobalSettings, GlobalSettings.PrintProduct, Repo}

  @prints_whcc_ids ~w(aeAXpFbKeRbvzGxxs BBrgfCJLkGzseCdds)
  @fine_art_types ~w(smooth_matte photo_rag_metallic torchon)
  @photo_print_types ~w(deep_matte glossy lustre)

  @shortdoc "Update Print Products"
  def run(_) do
    load_app()

    gallery_products = get_gallery_products()

    PrintProduct
    |> join(:inner, [print_product], product in assoc(print_product, :product))
    |> where([_, product], product.whcc_id in ^@prints_whcc_ids)
    |> Repo.all()
    |> Enum.reduce(Multi.new(), fn %{id: id} = print_product, multi ->
      sizes = build_sizes(gallery_products, print_product)
      Multi.update(multi, id, PrintProduct.changeset(print_product, %{sizes: sizes}))
    end)
    |> Repo.transaction()
  end

  defp build_sizes(gp_params, %{sizes: sizes}) do
    [_smoot_matte, photo_rag, torchon] = @fine_art_types

    Enum.reduce(sizes, [], fn size, acc ->
      case size do
        %{type: type} when type in @fine_art_types or type in @photo_print_types ->
          build_sizes(acc, gp_params, size, type)

        size ->
          acc
          |> build_sizes(gp_params, size, photo_rag)
          |> build_sizes(gp_params, Map.delete(size, :id), torchon)
      end
    end)
  end

  defp build_sizes(acc, gp_params, %{final_cost: final_cost, size: size} = obj, type) do
    obj = Map.take(obj, [:id, :size])
    %{base_cost: base_cost} = Map.get(gp_params, size <> type)
    final_cost = base_cost |> Money.to_decimal() |> Decimal.max(final_cost)

    [Map.merge(obj, %{final_cost: final_cost, type: type}) | acc]
  end

  def get_gallery_products() do
    GlobalSettings.gallery_products_params()
    |> Enum.find(&(&1.global_settings_print_products != []))
    |> Map.get(:global_settings_print_products)
    |> Enum.map(&Map.get(&1, :sizes))
    |> Enum.concat()
    |> Map.new(&{&1.size <> &1.type, &1})
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
