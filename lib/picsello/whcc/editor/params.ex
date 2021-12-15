defmodule Picsello.WHCC.Editor.Params do
  @moduledoc "Editor creation params builder"
  alias Picsello.Repo
  alias Picsello.Product
  alias Picsello.Galleries
  alias Picsello.WHCC.Editor.PhotoParams

  @multi_photo_categories ["Press Printed Cards", "Albums", "Books"]

  def build(%Product{} = product, photo, opts) do
    product = product |> Repo.preload(:category)

    favorites_only = Keyword.get(opts, :favorites_only, false)

    gallery =
      Galleries.get_gallery!(photo.gallery_id)
      |> Repo.preload(job: [client: :organization])

    gallery_photos =
      if product.category.whcc_name in @multi_photo_categories do
        gallery |> Galleries.load_gallery_photos((favorites_only && "favorites") || "all")
      else
        []
      end

    organization = gallery.job.client.organization

    color = Picsello.Profiles.color(organization)

    %{
      "userId" => "{{accountId}}",
      "productId" => product.whcc_id,
      "photos" => PhotoParams.from(photo, gallery_photos),
      "redirects" => redirects(opts),
      "settings" => settings(organization.name, color),
      "selections" => selections(opts)
    }
    |> add_design(Keyword.get(opts, :design))
  end

  defp add_design(selected_params, nil), do: selected_params
  defp add_design(selected_params, id), do: Map.put(selected_params, "designId", id)

  defp selections(opts), do: selections(%{}, opts)

  defp selections(_, [{:selections, selected_params} | rest]),
    do: selections(selected_params, rest)

  defp selections(selected_params, [{:size, size} | rest]),
    do:
      selected_params
      |> put_in(["size"], size)
      |> selections(rest)

  defp selections(selected_params, []), do: selected_params
  defp selections(selected_params, [_ | rest]), do: selections(selected_params, rest)

  defp settings(name, color) do
    %{
      "client" => %{
        "vendor" => "default",
        "accentColor" => color,
        "hidePricing" => true,
        "studioName" => name,
        "markupType" => "PERCENT",
        "markupAmount" => 0
      }
    }
  end

  defp redirects(opts) do
    %{
      "complete" => %{
        "url" => Keyword.get(opts, :complete_url, ""),
        "text" => Keyword.get(opts, :complete_text, "Save Product")
      },
      "cancel" => %{
        "url" => Keyword.get(opts, :cancel_url, ""),
        "text" => Keyword.get(opts, :cancel_text, "Cancel")
      }
    }
  end
end
