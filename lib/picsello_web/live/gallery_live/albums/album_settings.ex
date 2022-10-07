defmodule PicselloWeb.GalleryLive.Albums.AlbumSettings do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.Albums
  alias Picsello.Galleries.Album
  alias Picsello.Galleries.Gallery

  @impl true
  def update(%{gallery_id: gallery_id} = assigns, socket) do
    album = Map.get(assigns, :album, nil)
    is_mobile = Map.get(assigns, :is_mobile)
    selected_photos = Map.get(assigns, :selected_photos, [])
    is_finals = Map.get(assigns, :is_finals, false)
    is_redirect = Map.get(assigns, :is_redirect)

    socket
    |> assign(
      album: album,
      selected_photos: selected_photos,
      gallery_id: gallery_id,
      is_finals: is_finals,
      is_mobile: is_mobile,
      is_redirect: is_redirect
    )
    |> assign_album_changeset()
    |> assign(:visibility, false)
    |> then(fn socket ->
      if album do
        socket
        |> assign(:title, "Album Settings")
        |> assign(:set_password, album.set_password)
        |> assign(:album_password, album.password)
        |> assign(:action, "Save")
      else
        socket
        |> assign(:title, if(is_finals, do: "Add finals album", else: "Add Album"))
        |> assign(:action, if(is_finals, do: "Create finals album", else: "Create new album"))
        |> assign(
          set_password: false,
          album_password: nil
        )
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
            is_finals: is_finals,
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
        is_finals: is_finals,
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
        %{
          assigns: %{
            album_password: album_password
          }
        } = socket
      ) do
    set_password = String.to_existing_atom(params["set_password"])
    password = generate_password(set_password, album_password)

    socket
    |> assign_album_changeset(params)
    |> assign(:set_password, set_password)
    |> assign(:album_password, password)
    |> noreply
  end

  @impl true
  def handle_event("toggle_visibility", _, %{assigns: %{visibility: visibility}} = socket) do
    socket
    |> assign(:visibility, !visibility)
    |> noreply
  end

  @impl true
  def handle_event("regenerate", _params, socket) do
    socket
    |> assign(:album_password, Gallery.generate_password())
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

  defp generate_password(set_password, album_password) do
    if set_password && is_nil(album_password) do
      Gallery.generate_password()
    else
      album_password
    end
  end

  defp assign_album_changeset(
         %{assigns: %{album: album, gallery_id: gallery_id}} = socket,
         attrs \\ %{}
       ) do
    changeset =
      if(album,
        do: Albums.change_album(album, attrs),
        else: Albums.change_album(%Album{set_password: false, gallery_id: gallery_id}, attrs)
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
      <%= if @is_finals do%>
        <.finals_banner/>
      <% end %>
      <.form for={@changeset} let={f} phx-submit="submit" phx-change="validate" phx-target={@myself}>
        <%= labeled_input f, :name, label: "Album Name", placeholder: @album && @album.name, autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500"%>
        <%= hidden_input f, :gallery_id%>

        <div class="flex flex-col mt-3">
          <%= if is_nil(@album) && !@is_finals do %>
            <label class="flex items-center mb-4">
              <%= checkbox f, :is_proofing, class: "w-5 h-5 mr-2.5 checkbox cursor-pointer" %>
              Proofing album
            </label>
          <% end %>
          <h3 class="font-bold input-label">Password protection</h3>
          <label id="setPassword" class="flex text-1xl font-bold">
            <%= checkbox f, :set_password, class: "hidden peer", phx_debounce: 200 %>
            <div class="hidden peer-checked:flex">
              <div class="flex font-sans cursor-pointer justify-end items-center w-12 h-6 p-1 mr-4 border rounded-full bg-blue-planning-300 border-base-100">
                  <div class="w-4 h-4 rounded-full bg-base-100"></div>
              </div>
              <span>On</span>
            </div>
            <div class="flex peer-checked:hidden" >
              <div class="flex w-12 h-6 cursor-pointer items-center p-1 mr-4 border rounded-full border-blue-planning-300">
                  <div class="w-4 h-4 rounded-full bg-blue-planning-300"></div>
              </div>
              <span>Off</span>
            </div>
          </label>
          <%= if @set_password do %>
            <div class="relative mt-2">
              <%= if @visibility do %>
                <%= text_input f, :password, readonly: "readonly", value: @album_password, id: "visible-password",
                class: "gallerySettingsInput" %>
              <% else %>
                <%= password_input f, :password, readonly: "readonly", value: @album_password, id: "password",
                class: "gallerySettingsInput" %>
              <% end %>

              <div class="absolute flex h-full -translate-y-1/2 right-1 top-1/2">
                <a phx-click="toggle_visibility" phx-target={@myself} class="mr-4" id="toggle-visibility">
                  <%= if @visibility do %>
                    <.icon name="eye" class="w-5 cursor-pointer h-full ml-1 text-base-250"/>
                  <% else %>
                    <.icon name="closed-eye" class="w-5 h-full ml-1 text-base-250 cursor-pointer"/>
                  <% end %>
                </a>
                <button type="button" id="CopyToClipboardButton" phx-hook="Clipboard" data-clipboard-text={@album_password}
                  class="h-12 py-2 mt-1 border rounded-lg bg-base-100 border-blue-planning-300 text-blue-planning-300 w-36">
                  <div class="hidden p-1 text-sm rounded bg-white font-sans shadow" role="tooltip">
                      Copied!
                  </div>
                    Copy password
                </button>
              </div>
            </div>
            <div class="flex items-center justify-between w-full mt-2 lg:items-start">
              <button type="button" phx-click="regenerate" phx-target={@myself} class="p-4 font-bold cursor-pointer text-blue-planning-300 lg:pt-0" id="regenerate">
                  Re-generate
              </button>
            </div>
          <% end %>
        </div>
        <div class="flex flex-row items-center justify-end w-full mt-5 lg:items-start">
          <%= if @album do %>
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

  defp finals_banner(assigns) do
    ~H"""
      <div class="bg-orange-inbox-400 rounded-lg py-2">
        <div class="flex justify-center items-center mx-4">
          <.icon name="warning-orange", class="w-10 h-10 stroke-[4px]" />
          <div class="pl-4">
            <b>Note: </b>None of the photos in your finals album will be watermarked, and <b>all photos will be free to download.</b>
            Please ensure you only add photos to this album that you’ve already been financially compensated for.
          </div>
        </div>
      </div>
    """
  end
end
