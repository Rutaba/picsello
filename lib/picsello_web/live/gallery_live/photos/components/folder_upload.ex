defmodule PicselloWeb.GalleryLive.Photos.FolderUpload do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Albums

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:include_subfolders, true)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col modal rounded-lg sm:mb-8">
      <div class="flex items-start justify-between flex-shrink-0">
        <h1 class="mb-4 text-3xl font-bold">Folder Upload</h1>
        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
          <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>
      </div>

      <.form for={:folder_upload} let={f} phx-submit="submit" phx-change="change" phx-target={@myself} class="mt-8">
        <div class="py-4 pl-2 bg-base-200">
          <div class="flex">
            <.icon name="folder" class="w-6 h-6 mt-1 fill-blue-planning-300"/>
            <h2 class="ml-4 text-lg"><%= @folder %></h2>
          </div>

          <div class={classes("mt-2 ml-2", %{"hidden" => !@include_subfolders})}>
            <%= for folder <- @sub_folders do %>
              <div class="flex">
                <div class="relative w-6"><.icon name="dotted-l" class="absolute -top-3 w-6 h-6"/></div>
                <.icon name="folder" class="w-6 h-6 fill-base-200"/>
                <h3 class="ml-4"><%= Albums.folder_name(folder) %></h3>
              </div>
            <% end %>
          </div>
        </div>

        <label class="flex pl-2 items-center mt-4">
          <%= checkbox(f, :include_subfolders, class: "w-6 h-6 checkbox", value: @include_subfolders) %>
          <p class="ml-3">Upload sub-folders as albums</p>
        </label>

      <div class="flex justify-end">
        <button type="button" phx-click="modal" phx-value-action="close" class="btn-settings-secondary" id="close">
          Close
        </button>
        <%= submit "Next", class: "btn-settings ml-4 px-8", phx_disable_with: "Saving..." %>
      </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("change", _, %{assigns: %{include_subfolders: include_subfolders}} = socket) do
    socket
    |> assign(:include_subfolders, !include_subfolders)
    |> noreply()
  end

  def handle_event(
        "submit",
        %{"folder_upload" => %{"include_subfolders" => include_subfolders}},
        %{assigns: %{sub_folders: folders, gallery: gallery}} = socket
      ) do
    include_subfolders = String.to_atom(include_subfolders)

    if include_subfolders do
      case Albums.create_multiple(folders, gallery.id) do
        {:ok, albums} ->
          Phoenix.PubSub.broadcast(
            Picsello.PubSub,
            ~s(folder_albums:#{gallery.id}),
            {:folder_albums, albums}
          )
        {:error, _} -> put_flash(socket, :error, "Unable to upload folders as albums")
      end
    end

    socket
    |> close_modal()
    |> push_event("upload-photos", %{include_subfolders: include_subfolders})
    |> noreply
  end
end
