defmodule PicselloWeb.GalleryLive.Settings.UpdateNameComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  @impl true
  def update(%{id: id, gallery: gallery}, socket) do
    {:ok,
     socket
     |> assign(:id, id)
     |> assign(:gallery, gallery)
     |> assign_gallery_changeset()}
  end

  @impl true
  def handle_event("validate", %{"gallery" => %{"name" => name}}, socket) do
    socket
    |> assign_gallery_changeset(%{name: name})
    |> noreply
  end

  @impl true
  def handle_event(
        "save",
        %{"gallery" => %{"name" => name}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    {:ok, gallery} = Galleries.update_gallery(gallery, %{name: name})
    send(self(), {:update_name, %{gallery: gallery}})
    socket |> noreply
  end

  @impl true
  def handle_event("reset", _params, socket) do
    %{assigns: %{gallery: gallery}} = socket

    socket
    |> assign(:gallery, Galleries.reset_gallery_name(gallery))
    |> assign_gallery_changeset()
    |> noreply
  end

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket),
    do:
      socket
      |> assign(:changeset, Galleries.change_gallery(gallery) |> Map.put(:action, :validate))

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket, attrs),
    do:
      socket
      |> assign(
        :changeset,
        Galleries.change_gallery(gallery, attrs) |> Map.put(:action, :validate)
      )

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="font-sans">Gallery name</h3>
      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself} id="updateGalleryNameForm">
        <%= text_input f, :name, class: "gallerySettingsInput" %>
        <div class="flex items-center justify-between w-full mt-5 lg:items-start">
          <button type="button" phx-click="reset" phx-target={@myself} class="p-4 font-bold cursor-pointer text-blue-planning-300 lg:pt-0">Reset</button>
          <%= submit "Save", id: "saveGalleryName", class: "btn-settings font-sans w-32 px-11 cursor-pointer", disabled: !@changeset.valid?, phx_disable_with: "Saving..." %>
        </div>
      </.form>
    </div>
    """
  end
end
