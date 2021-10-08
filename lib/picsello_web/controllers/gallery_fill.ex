defmodule PicselloWeb.GalleryFillController do
  @moduledoc """
    Test galleries builder
  """

  use PicselloWeb, :controller

  import Ecto.Query

  alias Picsello.Galleries

  def new(conn, %{"hash" => hash}) when hash in ["Avery2"] do
    found = Galleries.get_gallery_by_hash(hash)

    if found == nil do
      build(hash)
    end

    redirect(conn, to: Routes.gallery_client_show_path(conn, :show, hash))
  end

  def new(conn, _) do
    redirect(conn, to: "/")
  end

  defp build("Avery2") do
    job_id = get_job_id()

    {:ok, gallery} =
      Galleries.create_gallery(%{
        name: "Avery only",
        status: "draft",
        job_id: job_id,
        client_link_hash: "Avery2"
      })

    data = [
      {1, "Avery-2-1.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-1.jpg"},
      {2, "Avery-2-2.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-2.jpg"},
      {3, "Avery-2-3.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-3.jpg"},
      {4, "Avery-2-4.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-4.jpg"},
      {5, "Avery-2-5.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-5.jpg"},
      {6, "Avery-2-6.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-6.jpg"},
      {7, "Avery-2-7.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-7.jpg"},
      {8, "Avery-2-8.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-8.jpg"},
      {9, "Avery-2-9.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-9.jpg"},
      {10, "Avery-2-10.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-10.jpg"},
      {11, "Avery-2-11.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-11.jpg"},
      {12, "Avery-2-12.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-12.jpg"},
      {13, "Avery-2-13.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-13.jpg"},
      {14, "Avery-2-14.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-14.jpg"},
      {15, "Avery-2-15.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-15.jpg"},
      {16, "Avery-2-16.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-16.jpg"},
      {17, "Avery-2-17.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-17.jpg"},
      {18, "Avery-2-18.jpg",
       "https://storage.googleapis.com/picsello-test-photos/Avery%20-%202/Avery-2-18.jpg"}
    ]

    photos =
      data
      |> Enum.map(fn {position, name, url} ->
        {:ok, photo} =
          Galleries.create_photo(%{
            gallery_id: gallery.id,
            name: name,
            original_url: url,
            client_copy_url: url,
            preview_url: url,
            position: position + 0.0
          })

        photo
      end)

    [cover | _] = photos

    Galleries.update_gallery(gallery, %{cover_photo_id: cover.id})
  end

  defp build(_), do: :ok

  defp find_or_create(model, create_function) do
    some =
      model
      |> limit(1)
      |> Picsello.Repo.one()

    if some do
      some.id
    else
      {:ok, new} = create_function.()

      new.id
    end
  end

  defp get_job_id() do
    find_or_create(Picsello.Job, fn ->
      client_id = get_client_id()

      %{client_id: client_id, type: "wedding"}
      |> Picsello.Job.create_changeset()
      |> Picsello.Repo.insert()
    end)
  end

  defp get_client_id() do
    find_or_create(Picsello.Client, fn ->
      organization_id = get_organization_id()

      %{
        organization_id: organization_id,
        name: "Test Client",
        email: "test@example.net",
        phone: "+5555555555"
      }
      |> Picsello.Client.create_changeset()
      |> Picsello.Repo.insert()
    end)
  end

  defp get_organization_id() do
    find_or_create(Picsello.Organization, fn ->
      %{name: "Test organization"}
      |> Picsello.Organization.registration_changeset()
      |> Picsello.Repo.insert()
    end)
  end
end
