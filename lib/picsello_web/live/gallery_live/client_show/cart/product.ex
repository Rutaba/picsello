defmodule PicselloWeb.GalleryLive.ClientShow.Cart.Product do
  @moduledoc false
  use PicselloWeb, :live_component

  defp product_size(%{editor_details: %{"selections" => %{"size" => size}}}), do: size
  defp product_preview_url(%{editor_details: %{"preview_url" => url}}), do: url
end
