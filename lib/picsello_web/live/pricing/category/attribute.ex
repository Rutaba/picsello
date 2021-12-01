defmodule PicselloWeb.Live.Pricing.Category.Attribute do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Markup

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> then(fn %{assigns: assigns} = socket ->
      socket
      |> assign(changeset: assigns |> build_markup() |> Markup.changeset(%{}))
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="contents">
        <%# desktop %>
        <div class="items-center hidden py-8 pl-12 pr-4 font-bold capitalize sm:flex"><%= @attribute.category_name %> <%= @attribute.name %></div>
        <div class="items-center hidden px-4 py-8 sm:flex"><%= @attribute.price %></div>
        <div class="items-center hidden px-4 py-8 sm:flex"><%= final_price(@attribute, @changeset) %></div>
        <div {testid("profit")} class="items-center hidden px-4 py-8 sm:flex"><%= profit(@attribute, @changeset) %></div>

        <div class="items-center hidden px-4 py-8 sm:flex">
          <.markup_form id={"desktop-#{@id}"} changeset={@changeset} myself={@myself} class="w-20 text-right text-input" />
        </div>

        <%# mobile %>
        <div class="px-5 py-4 mt-4 text-lg font-bold capitalize border-t border-l rounded-tl-lg ml-14 sm:hidden"><%= @attribute.category_name %> <%= @attribute.name %></div>
        <div class="py-4 mt-4 border-t border-r rounded-tr-lg pl-14 sm:hidden"><%= profit(@attribute, @changeset) %></div>
        <hr class="block ml-20 mr-6 sm:hidden col-span-2" />

        <dl class="block py-2 pl-5 border-l ml-14 sm:hidden">
          <dt class="font-bold">Base Cost</dt>
          <dd><%= @attribute.price %></dd>
        </dl>

        <dl class="py-2 border-b border-r rounded-br-lg pl-14 row-span-2 sm:hidden">
          <dt class="mb-4 font-bold">Markup</dt>
          <dd>
            <.markup_form id={"mobile-#{@id}"} changeset={@changeset} myself={@myself} class="w-20 px-3 py-4 text-center text-input" />
          </dd>
        </dl>

        <dl class="block pt-2 pb-3 pl-5 border-b border-l rounded-bl-lg ml-14 sm:hidden">
          <dt class="font-bold">Final price</dt>
          <dd><%= final_price(@attribute, @changeset) %></dd>
        </dl>
    </div>
    """
  end

  @impl true
  def handle_event(
        "change",
        %{"markup" => params},
        %{assigns: %{update: {update_component, update_id}} = assigns} = socket
      ) do
    changeset =
      assigns
      |> build_markup()
      |> Markup.changeset(params)
      |> Map.put(:action, :validate)

    unless Keyword.has_key?(changeset.errors, :value),
      do:
        send_update(update_component,
          id: update_id,
          markup: Ecto.Changeset.apply_changes(changeset)
        )

    socket
    |> assign(changeset: changeset)
    |> noreply()
  end

  defp markup_form(assigns) do
    ~H"""
    <.form for={@changeset} let={f} phx-submit="change" phx-change="change" phx-target={@myself} id={"form-#{@id}"}>
    <%= input f, :value, "markup" |> testid() |> Map.to_list() |> Enum.concat(class: @class, id: "input-#{@id}", phx_hook: "PercentMask", phx_debounce: 300, phx_update: "ignore") %>
    </.form>
    """
  end

  defp final_price(%{price: price} = attribute, changeset) do
    Money.add(price, profit(attribute, changeset))
  end

  defp profit(%{price: price}, changeset) do
    Money.multiply(price, markup(changeset) / 100)
  end

  defp build_markup(%{
         variation_id: whcc_variation_id,
         attribute: %{
           category_id: whcc_attribute_category_id,
           id: whcc_attribute_id,
           markup: value
         }
       }),
       do: %Markup{
         whcc_attribute_id: whcc_attribute_id,
         whcc_attribute_category_id: whcc_attribute_category_id,
         whcc_variation_id: whcc_variation_id,
         value: value
       }

  defp markup(changeset), do: Ecto.Changeset.get_field(changeset, :value)
end
