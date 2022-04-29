defmodule PicselloWeb.GalleryLive.FramedPreviewComponent do
  @moduledoc "renders hook and required markup for dynamic framing of a photo"

  use Phoenix.Component

  alias Picsello.{Photos, Category, Galleries.Photo}

  @defaults %{
    width: 300,
    height: 255,
    class: "bg-gray-300",
    preview: nil
  }

  def framed_preview(assigns) do
    config = to_config(assigns)

    assigns =
      assigns
      |> assign(@defaults)
      |> assign(:config, config)
      |> assign_new(:id, fn -> to_id(config) end)

    ~H"""
    <canvas
      class={@class}
      data-config={Jason.encode!(@config)}
      height={@height}
      id={@id}
      phx-hook="Preview"
      width={@width}>
    </canvas>
    """
  end

  defp to_config(%{photo: %Photo{} = photo} = assigns) do
    assigns
    |> Map.drop([:photo])
    |> Map.put(:preview, Photos.preview_url(photo, blank: true))
    |> to_config()
  end

  defp to_config(%{category: category} = assigns) do
    assigns
    |> Map.drop([:category])
    |> Map.merge(%{
      frame: Category.frame_image(category),
      coords: Category.coords(category)
    })
    |> to_config()
  end

  defp to_config(assigns), do: Map.take(assigns, [:preview, :frame, :coords, :item_id])

  defp to_id(%{item_id: item_id}), do: "canvas-#{item_id}"

  defp to_id(%{preview: preview_url, frame: frame_url}),
    do: Enum.join([preview_url, frame_url], "-")
end
