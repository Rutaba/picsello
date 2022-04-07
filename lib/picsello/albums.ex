defmodule Picsello.Albums do
  @moduledoc """
  The Albums context.
  """

  import Ecto.Query, warn: false

  alias Picsello.Repo
  alias Picsello.Galleries.Album

  @doc """
  Returns the list of albums.

  ## Examples

      iex> list_albums()
      [%Album{}, ...]

  """
  def list_albums do
    Repo.all(Album)
  end

  @doc """
  Gets a single album.

  Raises `Ecto.NoResultsError` if the Gallery does not exist.

  ## Examples

      iex> get_album!(123)
      %Album{}

      iex> get_album!(456)
      ** (Ecto.NoResultsError)

  """
  def get_album!(id), do: Repo.get!(Album, id)

  @doc """
  Update album
  """
  def update_album(album, params \\ %{}),
    do: album |> Album.update_changeset(params) |> Repo.update()
end
