defmodule PicselloWeb.GalleryLive.GalleriesCovers do
  @moduledoc false
  use PicselloWeb, :live_component
  require Logger
  import Ecto.Changeset
  alias Picsello.Repo
  alias Picsello.Galleries.GalleriesCovers
  alias Picsello.Galleries.Workers.PhotoStorage

  def update(%{preview: preview}, socket) do
    socket
    |> assign(:preview, path(preview))
    |> assign(:photo_id, nil)
    |> assign(:changeset, changeset(%{}, []))
    |> ok
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.GalleriesCovers{}, data, prop)
    |> validate_required([:photo_id])
  end

  def handle_event("set_preview", %{"preview" => preview, "photo_id" => photo_id}, socket) do
    socket
    |> assign(:photo_id, photo_id)
    |> assign(:preview, path(preview))
    |> assign(:changeset, changeset(%{photo_id: photo_id}, [:photo_id]))
    |> noreply
  end

  def render(assigns) do
    ~H"""
    <div class="inline-flex">
        <div class="preview" id="preview-photo">
          <img src={@preview} id="preview">
        </div>
        <div class="description">
        Lorem Ipsum
            <.form let={f} for={@changeset} action="#" phx-submit="save" id="preview_component">
                <%= hidden_input f, :photo_id, value: @photo_id %>
                <%= submit "Save", class: "btn-primary mt-5 px-11 py-3.5 float-right cursor-pointer",
                    disabled: !@changeset.valid?, phx_disable_with: "Saving..." %>
            </.form>
        </div>
    </div>
    """
  end

  def path(nil), do: "/images/card_blank.png"
  def path(url), do: PhotoStorage.path_to_url(url)
end
