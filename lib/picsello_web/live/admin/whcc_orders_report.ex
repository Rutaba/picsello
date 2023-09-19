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
    <div class="w-screen text-xs">
      <table class="w-full table-fixed">
        <tr class="border border-2">
          <th> Sr. No. </th>
          <th> Order Number </th>
          <th> Gallery Name </th>
          <th> Photographer </th>
          <th> Client </th>
          <th> Placed on </th>
          <th> Confirmed on </th>
          <th> WHCC Order No. </th>
          <th> Tracking </th>
          <th> Price Breakdown </th>
        </tr>
        <%= for({%{number: number, placed_at: placed_at} = order, index} <- @orders |> Enum.with_index()) do %>
          <tr class="text-center w-full">
            <td class="py-1"><%= index + 1 %></td>
            <td class="py-1"><%= number %></td>
            <td class="break-words py-1"><%= gallery_name(order) %></td>
            <td class="break-words py-1"><%= photogrpaher_email(order) %></td>
            <td class="break-words py-1"><%= client_email(order) %></td>
            <td class="py-1"><%= DateTime.to_date(placed_at) %></td>
            <td class="py-1"><%= confirmed_at(order) %></td>
            <td class="py-1"><%= tracking_info(order) |> Map.get(:whcc_order_number) %></td>
            <td class="break-words py-1">
              <a class="underline" href={"#{tracking_info(order) |> Map.get(:url)}"} target="_blank"><%= tracking_info(order) |> Map.get(:url) %></a>
            </td>
            <td class="py-1"><%= live_redirect "View Breakdown", to: Routes.admin_whcc_orders_pricing_report_path(@socket, :index, number), class: "underline" %></td>
          </tr>
        <% end %>
      </table>
    </div>
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
          %{shipping_info: [%{tracking_url: url}], order_number: whcc_order_number} = tracking
          %{url: url, whcc_order_number: whcc_order_number}
        else
          %{url: nil, whcc_order_number: nil}
        end
    end)
  end
end
