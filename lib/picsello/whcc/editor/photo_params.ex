defmodule Picsello.WHCC.Editor.PhotoParams do
  @moduledoc "Photo params preparation for WHCC editor cration"
  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.Workers.PhotoStorage

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

  defp make_photo(photo) do
    %{
      "id" => "photo-#{photo.id}",
      "name" => photo.name,
      "url" => photo.preview_url |> storage_service().path_to_url(),
      "printUrl" => photo.original_url |> storage_service().path_to_url(),
      "size" => %{
        "original" => %{
          "width" => photo.width,
          "height" => photo.height
        }
      }
    }
  end

  defp storage_service() do
    Application.get_env(:picsello, :photo_storage_service, PhotoStorage)
  end
end
