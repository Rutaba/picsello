defmodule Picsello.Repo.Migrations.UpdateAlbumPositions do
  use Ecto.Migration

  import Ecto.Query

  alias Picsello.Repo
  alias Picsello.Galleries.Album
  alias Picsello.Albums

  def change do
    albums =
      from("albums", select: [:id, :name, :gallery_id])
      |> Repo.all()
      |> Enum.group_by(& &1.gallery_id)

    albums_sorted =
      Enum.map(albums, fn {gallery_id, albums} ->
        sorted_albums = Enum.sort_by(albums, & &1.name)
        {gallery_id, sorted_albums}
      end)

    position_added =
      Enum.map(albums_sorted, fn {gallery_id, albums} ->
        {gallery_id,
         Enum.with_index(albums, fn album, position ->
           Map.put(album, :position, position + 1)
         end)}
      end)

    flattened = Enum.flat_map(position_added, fn {gallery_id, albums} -> albums end)

    Enum.map(flattened, fn album ->
      Albums.get_album!(album.id)
      |> Album.update_changeset(%{position: album.position})
      |> Repo.update!()
    end)
  end
end
