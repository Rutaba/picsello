defmodule Picsello.WHCC.Editor.PhotoParams do
  @moduledoc "Photo params preparation for WHCC editor cration"
  alias Picsello.{Photos, Galleries.Photo}

  def from(%Photo{} = photo, []) do
    [photo |> make_photo()]
  end

  def from(%Photo{} = photo, gallery_photos) do
    rest =
      gallery_photos
      |> Enum.reject(fn x -> x.id == photo.id end)

    [photo | rest]
    |> Enum.map(&make_photo/1)
  end

  def id(%{id: photo_id}), do: "photo-#{photo_id}"

  defp make_photo(photo) do
    %{
      "id" => id(photo),
      "name" => photo.name,
      "url" => Photos.preview_url(photo),
      "printUrl" => Photos.original_url(photo),
      "size" => %{
        "original" => %{
          "width" => photo.width,
          "height" => photo.height
        }
      }
    }
  end
end
