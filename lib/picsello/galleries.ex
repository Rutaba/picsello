defmodule Picsello.Galleries do
  @moduledoc """
  The Galleries context.
  """

  import Ecto.Query, warn: false
  alias Picsello.Repo

  alias Picsello.Galleries.{Gallery, Photo}

  @doc """
  Returns the list of galleries.

  ## Examples

      iex> list_galleries()
      [%Gallery{}, ...]

  """
  def list_galleries do
    Repo.all(Gallery)
  end

  @doc """
  Gets a single gallery.

  Raises `Ecto.NoResultsError` if the Gallery does not exist.

  ## Examples

      iex> get_gallery!(123)
      %Gallery{}

      iex> get_gallery!(456)
      ** (Ecto.NoResultsError)

  """
  def get_gallery!(id), do: Repo.get!(Gallery, id)


  @doc """
  Gets a single gallery by hash parameter.

  Returns nil if the Gallery does not exist.

  ## Examples

      iex> get_gallery_by_hash("validhash")
      %Gallery{}

      iex> get_gallery!("wronghash")
      nil

  """
  def get_gallery_by_hash(hash) do
    Repo.get_by(Gallery, client_link_hash: hash)
  end

  @doc """
  Creates a gallery.

  ## Examples

      iex> create_gallery(%{field: value})
      {:ok, %Gallery{}}

      iex> create_gallery(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_gallery(attrs \\ %{}) do
    %Gallery{}
    |> Gallery.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a gallery.

  ## Examples

      iex> update_gallery(gallery, %{field: new_value})
      {:ok, %Gallery{}}

      iex> update_gallery(gallery, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_gallery(%Gallery{} = gallery, attrs) do
    gallery
    |> Gallery.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a gallery.

  ## Examples

      iex> delete_gallery(gallery)
      {:ok, %Gallery{}}

      iex> delete_gallery(gallery)
      {:error, %Ecto.Changeset{}}

  """
  def delete_gallery(%Gallery{} = gallery) do
    Repo.delete(gallery)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking gallery changes.

  ## Examples

      iex> change_gallery(gallery)
      %Ecto.Changeset{data: %Gallery{}}

  """
  def change_gallery(%Gallery{} = gallery, attrs \\ %{}) do
    Gallery.update_changeset(gallery, attrs)
  end
  
  @doc """
  Creates a photo.

  ## Examples

      iex> create_photo(%{field: value})
      {:ok, %Photo{}}

      iex> create_photo(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_photo(%{} = attrs) do
    attrs
    |> Photo.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Gets a single photo by id.

  Returns nil if the Photo does not exist.

  ## Examples

      iex> get_photo(123)
      %Photo{}

      iex> get_photo(44545)
      nil

  """
  def get_photo(id), do: Repo.get(Photo, id)

  @doc """
  Marks a photo as liked/unliked.

  ## Examples

      iex> mark_photo_as_liked(%Photo{client_liked: false})
      {:ok, %Photo{client_liked: true}}

      iex> mark_photo_as_liked(%Photo{client_liked: true})
      {:ok, %Photo{client_liked: false}}

  """
  def mark_photo_as_liked(%Photo{client_liked: client_liked} = photo) do
    photo
    |> Photo.update_changeset(%{client_liked: !client_liked})
    |> Repo.update()
  end
end
