defmodule PicselloWeb.GalleryLive.FramedPreviewComponent do
  @moduledoc "renders hook and required markup for dynamic framing of a photo"

  use Phoenix.Component

  alias Picsello.{Photos, Category, Galleries.Photo}

  def framed_preview(%{photo: %Photo{width: w, height: h}} = assigns)
      when is_integer(w) and is_integer(h) do
    assigns = assign_new(assigns, :category, fn -> %Category{} end)

    assigns = assign(assigns, :frame, frame(assigns))
    assigns = assign(assigns, default_dims(assigns))
    assigns = assign(assigns, :config, to_config(assigns))
    assigns = assign_new(assigns, :id, fn -> to_id(assigns) end)

    ~H"""
    <canvas
      data-config={Jason.encode!(@config)}
      height={@height}
      id={@id}
      phx-hook="Preview"
      width={@width}>
    </canvas>
    """
  end

  def framed_preview(assigns) do
    assigns
    |> assign(
      :photo,
      %Photo{
        width: 1120,
        height: 1100,
        original_url: static_image_path(["card_blank.png"])
      }
    )
    |> framed_preview()
  end

  defp frame(%{category: category, photo: %{width: photo_w, height: photo_h}}) do
    orientation = if photo_w > photo_h, do: :landscape, else: :portrait

    case Category.frame(category) do
      nil ->
        %{w: photo_w, h: photo_h, slot: %{x: 0, y: 0, w: photo_w, h: photo_h}, url: nil}

      %{^orientation => %{image: image} = frame} ->
        frame
        |> Map.drop([:image])
        |> Map.put(
          :url,
          static_image_path(["frames", "#{image}.png"])
        )
    end
  end

  defp to_config(%{
         photo: %Photo{} = photo,
         width: canvas_w,
         height: canvas_h,
         frame: frame
       }) do
    %{w: frame_w, h: frame_h, slot: slot} = frame

    %{
      frame: %{
        url: frame.url,
        src: %{x: 0, y: 0, w: frame_w, h: frame_h},
        dest: %{x: 0, y: 0, w: canvas_w, h: canvas_h}
      },
      preview: %{
        url: Photos.preview_url(photo),
        dest: scale(slot, %{w: canvas_w, h: canvas_h}, %{w: frame_w, h: frame_h})
      }
    }
  end

  defp to_id(%{item_id: item_id}), do: "canvas-#{item_id}"

  defp to_id(%{config: %{preview: %{url: preview_url}, frame: %{url: frame_url}}}),
    do: Enum.join([preview_url, frame_url], "-")

  defp default_dims(%{frame: %{w: w, h: h}} = assigns) do
    default_dims(w / h, Map.take(assigns, [:width, :height]))
  end

  defp default_dims(aspect_ratio, %{width: width}) when is_number(width) do
    %{width: width, height: trunc(width / aspect_ratio)}
  end

  defp default_dims(aspect_ratio, %{height: height}) when is_number(height) do
    %{width: trunc(height * aspect_ratio), height: height}
  end

  defp default_dims(aspect_ratio, _) do
    default_dims(aspect_ratio, %{
      if aspect_ratio > 1 do
        :width
      else
        :height
      end => 300
    })
  end

  defp scale(slot, canvas, frame) do
    ratio_x = canvas.w / frame.w
    ratio_y = canvas.h / frame.h

    %{
      x: slot.x * ratio_x,
      y: slot.y * ratio_y,
      w: slot.w * ratio_x,
      h: slot.h * ratio_y
    }
  end

  defp static_image_path(segments) do
    Path.join(["/", "images"] ++ segments)
    |> PicselloWeb.Endpoint.static_path()
  end
end
