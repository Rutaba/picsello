defmodule PicselloWeb.GalleryLive.UpdatePreviewPhoto do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries
  alias Ecto.Changeset
  use Ecto.Schema

  schema "preview" do
    field :preview, :string
  end

  @impl true
  # def update(data, socket) do

  def update(data, socket) do
      IO.puts "_______!!()!!________"
    IO.inspect data
    {:ok,
     socket
     |> assign(:changeset, Ecto.Changeset.cast(%PicselloWeb.GalleryLive.UpdatePreviewPhoto{},%{},[]))}
    # |> assign(:product_preview, gallery.product_preview)
    # |> assign(:changeset, )
    #  |> assign_gallery_changeset()}
  end

  @impl true
  def handle_event("validate", d, socket) do
    IO.puts "()()()()()()()()()()("
    IO.inspect d
    socket
    |> noreply
  end

  @impl true
  def handle_event("set_preview", _, socket) do
    IO.inspect "**************************"
    # %{assigns: %{gallery: gallery}} = socket
    # {:ok, gallery} = Galleries.update_gallery(gallery, %{name: name})

    socket
#    |> assign(:gallery, gallery)
    |> noreply
  end

  @impl true
  def handle_event("save", %{"gallery" => %{"name" => name}}, socket) do
    %{assigns: %{gallery: gallery}} = socket
    {:ok, gallery} = Galleries.update_gallery(gallery, %{name: name})

    socket
    |> assign(:gallery, gallery)
    |> noreply
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
    do: socket |> assign(:changeset, Galleries.change_gallery(gallery))

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket, attrs),
    do: socket |> assign(:changeset, Galleries.change_gallery(gallery, attrs))
end
