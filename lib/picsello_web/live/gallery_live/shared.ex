defmodule PicselloWeb.GalleryLive.Shared do
  @moduledoc "Shared function among gallery liveViews"

  use Phoenix.Component
  import PicselloWeb.LiveHelpers, only: [icon: 1, testid: 1]
  import PicselloWeb.Gettext, only: [ngettext: 3]

  def assign_cart_count(
        %{assigns: %{order: %Picsello.Cart.Order{placed_at: %DateTime{}}}} = socket,
        _
      ),
      do: assign(socket, cart_count: 0)

  def assign_cart_count(%{assigns: %{order: %Picsello.Cart.Order{} = order}} = socket, _) do
    socket
    |> assign(cart_count: Picsello.Cart.item_count(order))
  end

  def assign_cart_count(socket, gallery) do
    case Picsello.Cart.get_unconfirmed_order(gallery.id) do
      {:ok, order} ->
        socket |> assign(order: order) |> assign_cart_count(gallery)

      _ ->
        socket |> assign(cart_count: 0, order: nil)
    end
  end

  def button(assigns) do
    assigns = Map.put_new(assigns, :class, "")

    assigns =
      Enum.into(assigns, %{
        element: "button",
        class: "",
        icon: "forth",
        icon_class: "h-3 w-2 stroke-current stroke-[3px]"
      })

    button_attrs = Map.drop(assigns, [:inner_block, :__changed__, :class, :icon, :icon_class])

    ~H"""
    <.button_element {button_attrs} class={"#{@class}
        flex items-center justify-center p-2 font-medium text-base-300 bg-base-100 border border-base-300 min-w-[12rem]
        hover:text-base-100 hover:bg-base-300
        disabled:border-base-250 disabled:text-base-250 disabled:cursor-not-allowed disabled:opacity-60
    "}>
      <%= render_slot(@inner_block) %>

      <.icon name={@icon} class={"#{@icon_class} ml-2"} />
    </.button_element>
    """
  end

  defp button_element(%{element: "a"} = assigns) do
    attrs = Map.drop(assigns, [:inner_block, :__changed__, :element])

    ~H"""
      <a {attrs}><%= render_slot(@inner_block) %></a>
    """
  end

  defp button_element(%{element: "button"} = assigns) do
    attrs = Map.drop(assigns, [:inner_block, :__changed__, :element])

    ~H"""
      <button {attrs}><%= render_slot(@inner_block) %></button>
    """
  end

  def summary_counts(order) do
    [
      products_summary(order),
      digitals_summary(Enum.filter(order.digitals, &Money.positive?(&1.price))),
      digital_credits_summary(Enum.filter(order.digitals, &Money.zero?(&1.price))),
      bundle_summary(order.bundle_price)
    ]
  end

  defp products_summary(%{products: []}), do: nil

  defp products_summary(order),
    do: {"Products (#{Enum.count(order.products)})", Picsello.Cart.Order.product_total(order)}

  defp digitals_summary([] = _digitals), do: nil

  defp digitals_summary(digitals),
    do: {"Digitals (#{Enum.count(digitals)})", sum_prices(digitals)}

  defp digital_credits_summary([] = _credits), do: nil

  defp digital_credits_summary(credits),
    do:
      {"Digital credits used (#{Enum.count(credits)})",
       "#{ngettext("%{count} credit", "%{count} credits", Enum.count(credits))} - #{sum_prices(credits)}"}

  defp bundle_summary(nil = _bundle_price), do: nil
  defp bundle_summary(bundle_price), do: {"Bundle - all digital downloads", bundle_price}

  defp sum_prices(collection) do
    Enum.reduce(collection, Money.new(0), &Money.add(&2, &1.price))
  end

  defdelegate price_display(product), to: Picsello.Cart

  def product_option(assigns) do
    assigns = Enum.into(assigns, %{min_price: nil})

    ~H"""
    <div {testid("product_option_#{@testid}")} class="p-5 mb-4 border rounded xl:p-7 border-base-225 lg:mb-7">
      <div class="flex items-center justify-between">
        <div class="flex flex-col mr-2">
          <p class="text-lg font-semibold text-base-300"><%= @title %></p>

          <%= if @min_price do %>
            <p class="font-semibold text-base text-base-300 pt-1.5 text-opacity-60"> <%= @min_price %></p>
          <% end %>
        </div>

        <%= for button <- @button do %>
          <.button {button}><%= render_slot(button) %></.button>
        <% end %>
      </div>
    </div>
    """
  end

  def bundle_image(assigns) do
    ~H"""
    <div class="relative w-full h-full">
      <%= for c <- ~w[-rotate-3 rotate-2 rotate-0] do %>
        <div class="absolute top-0 bottom-0 left-0 right-0 flex justify-center">
          <img src={@url} class={"h-full object-contain object-center shadow #{c}"}>
        </div>
      <% end %>
    </div>
    """
  end
end
