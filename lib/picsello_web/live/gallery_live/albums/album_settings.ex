defmodule PicselloWeb.GalleryLive.Albums.AlbumSettings do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Albums
  alias Picsello.Galleries.Album
  alias Picsello.Galleries.Gallery

  @impl true
  def update(%{gallery_id: gallery_id} = assigns, socket) do
    album = Map.get(assigns, :album, nil)

    changeset =
      if(album,
        do: Album.update_changeset(album),
        else: Album.create_changeset(%{set_password: false, gallery_id: gallery_id})
      )

    socket
    |> assign(:album, album)
    |> assign(:gallery_id, gallery_id)
    |> assign(:changeset, changeset)
    |> assign(:visibility, false)
    |> then(fn socket ->
      if album do
        socket
        |> assign(:title, "Album Settings")
        |> assign(:set_password, album.set_password)
        |> assign(:album_password, album.password)
      else
        socket
        |> assign(:title, "Add Album")
        |> assign(:set_password, false)
        |> assign(:album_password, nil)
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
            gallery_id: gallery_id
          }
        } = socket
      ) do
    if album do
      Albums.update_album(album, params)

      socket
      |> push_redirect(to: Routes.gallery_albums_index_path(socket, :index, gallery_id))
      |> put_flash(:gallery_success, "Album settings successfully updated")
      |> noreply()
    else
      Albums.insert_album(params)

      socket
      |> push_redirect(to: Routes.gallery_albums_index_path(socket, :index, gallery_id))
      |> put_flash(:gallery_success, "Album successfully created")
      |> noreply()
    end
  end

  def handle_event(
        "validate",
        %{"album" => params},
        %{
          assigns: %{
            album: album,
            album_password: album_password
          }
        } = socket
      ) do
    set_password = String.to_existing_atom(params["set_password"])

    changeset =
      if album do
        Album.update_changeset(album, %{set_password: set_password})
      else
        Album.create_changeset(params)
      end

    password = generate_password(set_password, album_password)

    socket
    |> assign(:changeset, changeset)
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

  defp generate_password(set_password, album_password) do
    if set_password && is_nil(album_password) do
      Gallery.generate_password()
    else
      album_password
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col modal" style="border-radius: 0.8rem;">
      <div class="flex items-start justify-between flex-shrink-0">
        <h1 class="mb-4 font-sans text-3xl font-bold"><%= @title %></h1>
        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
        <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>
      </div>
      <.form for={@changeset} let={f} phx-submit="submit" phx-change="validate" phx-target={@myself} class="font-sans">
        <%= labeled_input f, :name, label: "Album Name", placeholder: @album && @album.name, autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500", style: "border-radius: 0.5rem;"%>
        <%= hidden_input f, :gallery_id%>

        <div class="flex flex-col mt-4 font-bold">
          <h3 class="font-bold font-sans input-label">Password protection</h3>
          <label id="setPassword" class="flex text-1xl font-sans">
            <%= checkbox f, :set_password, class: "hidden peer", phx_debounce: 200 %>
            <div class="hidden peer-checked:flex font-sans">
              <div class="flex font-sans justify-end w-12 p-1 mr-4 border rounded-full bg-blue-planning-300 border-base-100">
                  <div class="w-6 h-6 rounded-full bg-base-100"></div>
              </div>
              <span class="mt-2">On</span>
            </div>
            <div class="flex peer-checked:hidden" >
              <div class="flex w-12 p-1 mr-4 border rounded-full border-blue-planning-300">
                  <div class="w-6 h-6 rounded-full bg-blue-planning-300"></div>
              </div>
              <span class="mt-2">Off</span>
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
                    <.icon name="eye" class="w-5 h-full ml-1 text-base-250"/>
                  <% else %>
                    <.icon name="closed-eye" class="w-5 h-full ml-1 text-base-250"/>
                  <% end %>
                </a>
                <button type="button" id="CopyToClipboardButton" phx-hook="Clipboard" data-clipboard-text={@album && @album.password}
                  class="h-12 py-2 mt-1 border rounded-lg bg-base-100 border-blue-planning-300 text-blue-planning-300 w-36">
                  <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
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
          <button type="button" phx-click="modal" phx-value-action="close" class="btn-settings-secondary" id="close">
            Close
          </button>
          <%= submit "Save", class: "btn-settings ml-4 px-11", disabled: !@changeset.valid?, phx_disable_with: "Saving..." %>
        </div>
      </.form>
    </div>
    """
  end
end
