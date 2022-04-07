defmodule PicselloWeb.GalleryLive.ProductPreview.Index do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  alias Picsello.{Galleries, Repo}
  alias PicselloWeb.GalleryLive.ProductPreview.Preview
  alias PicselloWeb.GalleryLive.Photos.Upload

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(total_progress: 0)
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id) |> Repo.preload(:albums)

    socket
    |> assign(
      gallery: gallery,
      page_title: page_title(socket.assigns.live_action),
      products: Galleries.products(gallery)
    )
    |> noreply()
  end

  @impl true
  def handle_info(
        {:save, %{title: title}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> close_modal()
    |> assign(products: Galleries.products(gallery))
    |> put_flash(:gallery_success, "#{title} successfully updated")
    |> noreply
  end

  @impl true
  def handle_event(
        "edit",
        %{"product_id" => product_id},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> open_modal(
      PicselloWeb.GalleryLive.ProductPreview.EditProduct,
      %{product_id: product_id, gallery_id: gallery.id}
    )
    |> noreply
  end

  @impl true
  def handle_event(
        "client-link",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    gallery = Picsello.Repo.preload(gallery, job: :client)

    link = Routes.gallery_client_show_url(socket, :show, hash)
    client_name = gallery.job.client.name

    subject = "#{gallery.name} photos"

    html = """
    <p>Hi #{client_name},</p>
    <p>Your gallery is ready to view! You can view the gallery here: <a href="#{link}">#{link}</a></p>
    <p>Your photos are password-protected, so you’ll also need to use this password to get in: <b>#{gallery.password}</b></p>
    <p>Happy viewing!</p>
    """

    text = """
    Hi #{client_name},

    Your gallery is ready to view! You can view the gallery here: #{link}

    Your photos are password-protected, so you’ll also need to use this password to get in: #{gallery.password}

    Happy viewing!
    """

    socket
    |> assign(:job, gallery.job)
    |> assign(:gallery, gallery)
    |> PicselloWeb.ClientMessageComponent.open(%{
      body_html: html,
      body_text: text,
      subject: subject,
      modal_title: "Share gallery",
      is_client_gallery: false
    })
    |> noreply()
  end

  @impl true
  def handle_info({:total_progress, total_progress}, socket) do
    socket |> assign(:total_progress, total_progress) |> noreply()
  end

  defp page_title(:index), do: "Product Previews"
end
