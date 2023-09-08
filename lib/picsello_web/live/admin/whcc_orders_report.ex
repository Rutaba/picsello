defmodule PicselloWeb.Live.Admin.WHCCOrdersReport do
  @moduledoc false
  use PicselloWeb, live_view: [layout: false]
  alias Picsello.{Orders}

  def mount(_, _, socket) do
    orders = Orders.get_whcc_orders()

    socket
    |> assign(orders: orders)
    |> ok()
  end

  def render(assigns) do
    ~H"""
      <table class="w-full">
        <tr class="border">
            <th> Order Number </th>
            <th> Gallery Name </th>
            <th> Photographer </th>
            <th> Client </th>
            <th> Placed on </th>
            <th> Confirmed on </th>
            <th> Tracking </th>
        </tr>

        <%= for %{number: number, placed_at: placed_at} = order <- @orders do %>
          <tr class="text-center">
            <td><%= number %></td>
            <td><%= gallery_name(order) %></td>
            <td><%= photogrpaher_email(order) %></td>
            <td><%= client_email(order) %></td>
            <td><%= DateTime.to_date(placed_at) %></td>
            <td><%= confirmed_at(order) %></td>
            <td><%= tracking_info(order) %></td>
          </tr>
        <% end %>
      </table>
    """
  end

  defp gallery_name(order), do: order.gallery.name
  defp client_email(order), do: order.gallery_client.email
  defp photogrpaher_email(order) do
    %{email: email} = Picsello.Accounts.get_user!(order.gallery.organization.id)
    email
  end
  defp confirmed_at(%{whcc_order: whcc_order}) do
    if whcc_order.confirmed_at, do: DateTime.to_date(whcc_order.confirmed_at), else: nil
  end
  defp tracking_info(%{whcc_order: %{orders: sub_orders}}) do
    Enum.find_value(sub_orders, fn
      %{whcc_tracking: tracking} ->
        if tracking do
          tracking.url
        else
          nil
        end
    end)
  end
end
