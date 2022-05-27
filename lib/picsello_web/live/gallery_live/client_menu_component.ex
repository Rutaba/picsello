defmodule PicselloWeb.GalleryLive.ClientMenuComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  import PicselloWeb.Live.Profile.Shared, only: [photographer_logo: 1]

  alias Picsello.Profiles

  @defaults %{
    cart_count: 0,
    cart_route: nil,
    cart: true
  }

  def update(assigns, socket) do
    socket
    |> assign(Map.merge(@defaults, assigns))
    |> then(fn %{assigns: %{gallery: gallery}} = socket ->
      assign(socket,
        organization: gallery.job.client.organization,
        cart_route: Routes.gallery_client_show_cart_path(socket, :cart, gallery.client_link_hash)
      )
    end)
    |> ok()
  end

  def get_menu_items(socket, gallery) do
    [
      %{
        title: "Home",
        path: Routes.gallery_client_index_path(socket, :index, gallery.client_link_hash)
      },
      %{
        title: "My orders",
        path: Routes.gallery_client_orders_path(socket, :show, gallery.client_link_hash)
      },
      %{
        title: "Help",
        path: extract_organization(gallery) |> Profiles.public_url()
      }
    ]
  end

  def cart_wrapper(assigns) do
    ~H"""
    <%= if @count > 0 do %>
      <%= live_redirect to: @route, title: "cart", class: "block" do %><%= render_slot @inner_block %><% end %>
    <% else %>
      <div title="cart" ><%= render_slot @inner_block %></div>
    <% end %>
    """
  end

  defp extract_organization(%{job: %{client: %{organization: organization}}}), do: organization
end
