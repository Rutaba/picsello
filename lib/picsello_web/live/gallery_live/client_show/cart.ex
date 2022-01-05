defmodule PicselloWeb.GalleryLive.ClientShow.Cart do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.Cart
  alias Picsello.WHCC.Shipping

  @impl true
  def mount(_params, _session, %{assigns: %{gallery: gallery}} = socket) do
    case Cart.get_unconfirmed_order(gallery.id) do
      {:ok, order} ->
        socket
        |> assign(:order, order)
        |> assign(:step, :product_list)
        |> ok()

      _ ->
        socket
        |> push_redirect(
          to: Routes.gallery_client_show_path(socket, :show, gallery.client_link_hash)
        )
        |> ok()
    end
  end

  @impl true
  def handle_event("continue", _, %{assigns: %{step: :product_list}} = socket) do
    socket
    |> assign(:step, :shipping_opts)
    |> assign_shipping_opts()
    |> assign_shipping_cost()
    |> noreply()
  end

  def handle_event(
        "click",
        %{"option-uid" => option_uid, "product-editor-id" => editor_id},
        %{assigns: %{step: :shipping_opts}} = socket
      ) do
    socket
    |> update_shipping_opts(String.to_integer(option_uid), editor_id)
    |> assign_shipping_cost()
    |> noreply()
  end

  defp update_shipping_opts(%{assigns: %{shipping_opts: opts}} = socket, option_uid, editor_id) do
    socket
    |> assign(
      :shipping_opts,
      Enum.map(opts, fn
        %{editor_id: id, current: {uid, _, _, _}} = opt
        when editor_id == id and option_uid == uid ->
          opt

        %{editor_id: id} = opt when editor_id == id ->
          Map.put(
            opt,
            :current,
            Enum.find(opt[:list], fn list_opt -> option_uid == elem(list_opt, 0) end)
          )

        opt ->
          opt
      end)
    )
  end

  defp assign_shipping_opts(
         %{assigns: %{step: :shipping_opts, order: %{products: products}}} = socket
       ) do
    socket
    |> assign(
      :shipping_opts,
      Enum.map(products, fn product -> shipping_opts_for_product(product) end)
    )
  end

  defp assign_shipping_cost(%{assigns: %{step: :shipping_opts, shipping_opts: opts}} = socket) do
    socket
    |> assign(
      :shipping_cost,
      Enum.reduce(opts, Money.new(0), fn %{current: {_, _, _, cost}}, sum ->
        cost |> Money.parse!() |> Money.add(sum)
      end)
    )
  end

  defp display_shipping_opts(assigns) do
    ~H"""
    <form>
      <%= for option <- @options do %>
        <%= render_slot(@inner_block, option) %>
      <% end %>
    </form>
    """
  end

  defp shipping_opts_for_product(%{
         editor_details: %{"editor_id" => editor_id, "selections" => %{"size" => size}}
       }) do
    %{editor_id: editor_id, list: Shipping.options(size)}
    |> (&Map.put(&1, :current, List.first(&1[:list]))).()
  end

  defp shipping_opts_for_product(opts, %{editor_details: %{"editor_id" => editor_id}}) do
    Enum.find(opts, fn %{editor_id: id} -> id == editor_id end)
    |> (& &1[:list]).()
  end

  defp is_current_shipping_option?(opts, option, %{editor_details: %{"editor_id" => editor_id}}) do
    Enum.find(opts, fn %{editor_id: id} -> id == editor_id end)
    |> (&(&1[:current] == option)).()
  end

  defp shipping_option_uid({uid, _, _, _}), do: uid
  defp shipping_option_cost({_, _, _, cost}), do: Money.parse!(cost)
  defp shipping_option_label({_, label, _, _}), do: label
end
