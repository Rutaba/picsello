defmodule PicselloWeb.Live.Admin.ProductPricing do
  @moduledoc false
  use PicselloWeb, live_view: [layout: false]

  import Ecto.Query, only: [from: 2]
  alias Picsello.{Category, Product, Repo}

  def mount(_, _, socket) do
    socket
    |> assign(
      categories: from(category in Category, preload: :products, order_by: :name) |> Repo.all()
    )
    |> ok()
  end

  def handle_params(%{"id" => product_id}, _uri, socket) do
    product = Repo.get!(Product, product_id) |> Repo.preload(:category)

    {category_names, rows} = rows(product)

    socket
    |> assign(
      product: product,
      attribute_category_names: category_names,
      rows: rows
    )
    |> noreply()
  end

  def handle_params(_, _uri, socket), do: socket |> assign(product: nil) |> noreply()

  def render(assigns) do
    ~H"""
      <ul class="flex p-8 border justify-evenly">
        <%= for %{name: name, products: [_|_] = products} <- @categories do %>
          <li>
            <%= name %>

            <ul class="pl-4 list-disc">
              <%= for %{whcc_name: name, id: id} <- products do %>
                <li>
                  <%= live_patch to: Routes.admin_product_pricing_path(@socket, :show, id) do %>
                    <%= name %>
                  <% end %>
                </li>
              <% end %>
            </ul>
          </li>
        <% end %>
      </ul>

      <%= if @product do %>
        <div class="flex items-center p-8">
          <h1 class="mr-4 text-lg font-bold"><%= @product.whcc_name %></h1>
          <p><%= @product.api |> Map.get("description") %></p>
        </div>

        <table class="mx-8 mb-8">
          <thead class="bg-base-200">
            <tr>
              <th colspan="5" class="p-2 border">pricing</th>
              <th colspan={length @attribute_category_names} class="p-2 border">selections</th>
            </tr>

            <tr>
              <th class="p-2 border">client price</th>
              <th class="p-2 border">whcc - print cost</th>
              <th class="p-2 border">user - markup</th>

              <%= for name <- @attribute_category_names do %>
                <th><%= name %></th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for row <- @rows do %>
              <tr>
                <%= for value <- row do %>
                  <td class="p-2 text-right border"><%= value %></td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    """
  end

  defp rows(%{attribute_categories: attribute_categories} = product) do
    {categories, rows} = Picsello.Product.selections_with_prices(product)

    {Enum.map(categories, fn id ->
       attribute_categories |> Enum.find(&(Map.get(&1, "_id") == id)) |> Map.get("name")
     end), Enum.sort_by(rows, &Enum.at(&1, 2))}
  end
end
