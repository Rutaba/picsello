defmodule PicselloWeb.GalleryLive.Album do
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries
  alias Picsello.Galleries.Workers.PhotoStorage
  alias Picsello.Galleries.Workers.PositionNormalizer
  import Ecto.Changeset
  use Ecto.Schema

  schema "preview" do
    field :preview, :string
  end

  @per_page 12

  def mount(params, _session, socket) do
    {:ok,
      socket
        |> assign(:preview, path(nil))
        |> assign(:changeset, changeset(%{},[:preview]))}
  end

  def update(data, socket) do
    IO.puts "________&&&&&+________"
    # IO.inspect socket.changeset
    {:ok,
      socket}
      #  |> assign(:changeset, changeset(%{},[:preview]))}
end

  def changeset(data, prop) do
    cast(%__MODULE__{},data,prop)
      |> validate_required([:preview])
  end



  @impl true
  # def handle_event("validate", d, socket) do
  #   IO.puts "()()()()()validate album()()()()()("
  #   IO.inspect socket.changeset
  #   chngset = socket.changeset |> validate_required([:preview])

  #   socket
  #   |> assign(:changeset, chngset)
  #   |> noreply
  # end


  # @impl true
  # def handle_event("start", _params, socket) do
  #   socket.assigns.uploads.cover_photo
  #   |> case do
  #     %{valid?: false, ref: ref} -> {:noreply, cancel_upload(socket, :cover_photo, ref)}
  #     _ -> {:noreply, socket}
  #   end
  # end

  @impl true
  def handle_event("set_preview", %{"preview-url" => name} = d, socket) do
    IO.puts "*****************"
    chngst = changeset(%{preview: name},[:preview])
      |> validate_required([:preview])

     s = socket
      |> assign(:preview, path(name))
      |> assign(:changeset, chngst)

      PositionNormalizer.normalize(5)
      #update([], s)
    {:noreply, s}
  end

  def handle_event(_,_,socket) do
    {:noreply, socket}
  end


  @impl true
  def handle_event("save",data, socket) do
    IO.puts "SSSSSSSSSSSSSSSSSS"
    %{assigns: %{preview: preview}} = socket
    gallery = Picsello.Galleries.get_gallery!(5)
    {:ok, gallery} = Galleries.update_gallery(gallery, %{product_preview: preview})

    socket
    |> assign(:gallery, gallery)
    |> noreply
  end

  @impl true
  def handle_event("reset", _params, socket) do
    %{assigns: %{gallery: gallery}} = socket

    socket
    |> assign(:gallery, Galleries.reset_gallery_name(gallery))
    #|> assign_gallery_changeset()
    |> noreply
  end


  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    socket
    |> assign(:gallery, gallery)
    |> assign(:page, 0)
    |> assign(:update_mode, "append")
    |> assign(:favorites_filter, false)
    |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
    |> assign_photos()
    # |> then(fn
    #   %{assigns: %{live_action: :upload}} = socket ->
    #     send(self(), :open_modal)
    #     socket

    #   socket ->
    #     socket
    # end)
    |> noreply()
  end

  def handle_cover_progress(:cover_photo, entry, %{assigns: assigns} = socket) do
    if entry.done? do
      {:ok, gallery} =
        Galleries.update_gallery(assigns.gallery, %{
          cover_photo_id: entry.uuid,
          cover_photo_aspect_ratio: 1
        })

      {:noreply, socket |> assign(:gallery, gallery)}
    else
      {:noreply, socket}
    end
  end

  defp assign_photos(
    %{
      assigns: %{
        gallery: %{id: id},
        page: page,
        favorites_filter: filter
      }
    } = socket
  ) do
    IO.puts"_________________________________"
    p = Galleries.get_gallery_photos(id, @per_page, page, only_favorites: filter)
        IO.inspect p
    assign(socket,
      photos: Galleries.get_gallery_photos(id, @per_page, page, only_favorites: filter)
    )
  end

  def path(nil), do: "/images/card_blank.png"
  def path(url), do: PhotoStorage.path_to_url(url)
end
