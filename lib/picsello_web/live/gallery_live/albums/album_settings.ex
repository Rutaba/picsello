defmodule PicselloWeb.GalleryLive.Albums.AlbumSettings do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Shared
  import PicselloWeb.Live.Shared, only: [make_popup: 2]

  alias Picsello.Albums
  alias Picsello.Galleries.Album

  @impl true
  def update(%{gallery_id: gallery_id} = assigns, socket) do
    album = Map.get(assigns, :album, nil)
    is_mobile = Map.get(assigns, :is_mobile)
    selected_photos = Map.get(assigns, :selected_photos, [])
    is_redirect = Map.get(assigns, :is_redirect)
    has_order? = Map.get(assigns, :has_order?, false)

    socket
    |> assign(
      album: album,
      selected_photos: selected_photos,
      gallery_id: gallery_id,
      is_mobile: is_mobile,
      is_redirect: is_redirect,
      has_order?: has_order?
    )
    |> assign_album_changeset()
    |> assign(:visibility, false)
    |> then(fn socket ->
      if album do
        socket
        |> assign(:title, "Album Settings")
        |> assign(:action, "Save")
      else
        socket
        |> assign(:title, "Add Album")
        |> assign(:action, "Create new album")
      end
    end)
    |> ok()
  end

  @impl true
  def handle_event(
        "submit",
        %{"album" => params},
        %{
          assigns: %{
            album: album,
            gallery_id: gallery_id,
            is_mobile: is_mobile,
            is_redirect: is_redirect
          }
        } = socket
      ) do
    create_album(
      album,
      %{
        params: params,
        gallery_id: gallery_id,
        is_mobile: is_mobile,
        is_redirect: is_redirect
      },
      socket
    )
  end

  @impl true
  def handle_event(
        "validate",
        %{"album" => params},
        socket
      ) do
    socket
    |> assign_album_changeset(params)
    |> noreply
  end

  @impl true
  def handle_event(
        "delete_album_popup",
        %{"id" => id},
        %{
          assigns: %{
            album: album,
            gallery_id: gallery_id
          }
        } = socket
      ) do
    albums = Albums.get_albums_by_gallery_id(gallery_id)

    opts = [
      event: "delete_album",
      title: "Delete album?",
      subtitle:
        "Are you sure you wish to delete #{album.name}? Any photos within this album will be moved to your #{ngettext("Photos", "Unsorted photos", length(albums))}.",
      payload: %{album_id: id}
    ]

    socket
    |> make_popup(opts)
  end

  defp assign_album_changeset(
         %{assigns: %{album: album, gallery_id: gallery_id}} = socket,
         attrs \\ %{}
       ) do
    changeset =
      if(album,
        do: Albums.change_album(album, attrs),
        else: Albums.change_album(%Album{gallery_id: gallery_id}, attrs)
      )

    socket
    |> assign(:changeset, changeset |> Map.put(:action, :validate))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col modal rounded-lg sm:mb-8">
      <div class="flex items-start justify-between flex-shrink-0">
        <h1 class="mb-4 text-3xl font-bold"><%= @title %></h1>
        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
        <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>
      </div>
      <.form for={@changeset} :let={f} phx-submit="submit" phx-change="validate" phx-target={@myself}>
        <%= labeled_input f, :name, label: "Album Name", placeholder: @album && @album.name, autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500"%>
        <%= hidden_input f, :gallery_id%>

        <div class="flex flex-row items-center justify-end w-full mt-5 lg:items-start">
          <%= if @album && !@has_order? && !@album.is_finals && !@album.is_proofing do %>
          <div class="flex flex-row items-center justify-start w-full lg:items-start">
            <button type="button" phx-click="delete_album_popup" phx-target={@myself} phx-value-id={@album.id} class="btn-settings-secondary flex items-center border-gray-200" id="close">
              <.icon name="trash" class="flex w-4 h-5 mr-2 text-red-400" />
              Delete
            </button>
          </div>
          <% end %>
          <button type="button" phx-click="modal" phx-value-action="close" class="btn-settings-secondary" id="close">
            Close
          </button>
          <%= submit @action, class: "btn-settings ml-4 px-11", disabled: !@changeset.valid?, phx_disable_with: "Saving..." %>
        </div>
      </.form>
    </div>
    """
  end
end
