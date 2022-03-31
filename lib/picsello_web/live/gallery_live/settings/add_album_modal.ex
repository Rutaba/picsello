defmodule PicselloWeb.GalleryLive.Settings.AddAlbumModal do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries
  alias Picsello.Galleries.Album
  alias Picsello.Repo
  alias Picsello.Galleries.Gallery

  @impl true
  def update(assigns, socket) do
    new =
      %{
        set_password: false,
        name: "",
        gallery_id: assigns[:gallery_id]
      }
      |> Album.create_changeset()

    socket
    |> assign(:changeset, new)
    |> assign(:gallery_id, assigns[:gallery_id])
    |> assign(:visibility, false)
    |> assign(:set_password, false)
    |> assign(:album_password, nil)
    |> ok()
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
  def handle_event("add-album-save", %{"album" => params}, socket) do
    Album.create_changeset(params)
    |> Repo.insert!()

    socket
    |> push_redirect(
      to:
        Routes.gallery_albums_path(socket, :albums, socket.assigns.gallery_id,
          upload_toast: false,
          upload_toast_text: "New Album Added"
        )
    )
    |> noreply()
  end

  def handle_event("validate", %{"album" => params}, socket) do
    password =
      if socket.assigns.changeset.changes.set_password !=
           String.to_existing_atom(params["set_password"]) and params["set_password"] == "true" do
        Gallery.generate_password()
      else
        socket.assigns.album_password
      end

    socket
    |> assign(:changeset, Album.create_changeset(params))
    |> assign(:set_password, params["set_password"] == "true")
    |> assign(:album_password, password)
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col modal">
      <div class="flex items-start justify-between flex-shrink-0">
        <h1 class="mb-4 text-3xl font-bold">Add Album</h1>
        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
        <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>
      </div>
      <.form for={@changeset} let={f} phx-submit="add-album-save" phx-change="validate" phx-target={@myself}>
        <%= labeled_input f, :name, label: "Album Name" , placeholder: "Enter album name", autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500", class: "font-sans" , label_class: "font-bold", style: "border-radius: 0.5rem" %>
        <%= hidden_input f, :gallery_id %>

        <div class="flex flex-col mt-4 font-bold">
          <h3 class="font-bold input-label" style="font-family: sans-serif">Password protection</h3>
          <label class="flex text-1xl">
            <%= checkbox f, :set_password, class: "hidden peer", phx_debounce: 200 %>
            <div class="hidden peer-checked:flex">
              <div class="flex justify-end w-12 p-1 mr-4 border rounded-full bg-blue-planning-300 border-base-100">
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
                <%= text_input f, :password, readonly: "readonly", value: @album_password, id: "galleryPasswordInput",
                class: "gallerySettingsInput" %>
              <% else %>
                <%= password_input f, :password, readonly: "readonly", value: @album_password, id: "galleryPasswordInput",
                class: "gallerySettingsInput" %>
              <% end %>

              <div class="absolute flex h-full -translate-y-1/2 right-1 top-1/2">
                <a href="#" phx-click="toggle_visibility" phx-target={@myself} class="mr-4" id="togglePasswordVisibility">
                  <%= if @visibility do %>
                    <.icon name="eye" class="w-5 h-full ml-1 text-base-250"/>
                  <% else %>
                    <.icon name="closed-eye" class="w-5 h-full ml-1 text-base-250"/>
                  <% end %>
                </a>
                <button type="button" id="CopyToClipboardButton" phx-hook="Clipboard" data-clipboard-text={@album_password}
                  class="h-12 py-2 mt-1 border rounded-lg bg-base-100 border-blue-planning-300 text-blue-planning-300 w-36">
                  <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
                      Copied!
                  </div>
                    Copy password
                </button>
              </div>
            </div>
            <div class="flex items-center justify-between w-full mt-2 lg:items-start">
              <button type="button" phx-click="regenerate" phx-target={@myself} class="p-4 font-bold cursor-pointer text-blue-planning-300 lg:pt-0" id="regeneratePasswordButton">
                  Re-generate
              </button>
            </div>
          <% end %>
        </div>
        <div class="flex flex-row items-center justify-end w-full mt-5 lg:items-start">
          <button type="button" phx-click="modal" phx-value-action="close" class={"py-3 mr-2 text-lg font-semibold border disabled:border-base-200 rounded-lg sm:self-end border-base-300 sm:w-36"} id="copy-public-profile-link">
          Close
          </button>
          <%= submit "Create new album", class: "album-btn-settings px-11 cursor-pointer", disabled: !@changeset.valid?, phx_disable_with: "Saving..." %>
        </div>
      </.form>
    </div>
    """
  end
end
