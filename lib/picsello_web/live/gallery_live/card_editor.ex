defmodule PicselloWeb.GalleryLive.CardEditor do
  @moduledoc """
    clients can filter and choose a card design to customize in WHCC
  """
  use PicselloWeb, live_view: [layout: "live_gallery_client"]

  import PicselloWeb.GalleryLive.Shared,
    only: [assign_cart_count: 2, customize_and_buy_product: 4]

  import Picsello.Designs, only: [load_occasion: 1, occasion_designs_query: 1, occasions: 0]

  import Ecto.Query, only: [from: 2]
  alias Picsello.{Repo, Designs.Filter}

  @per_page 16

  @impl true
  def mount(_, _, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign_cart_count(gallery)
    |> assign(update: "init", filter: nil, occasion: nil, show_filter_form: false)
    |> ok(temporary_assigns: [designs: []])
  end

  @impl true
  def handle_params(
        %{"occasion_id" => occasion_id} = params,
        _,
        socket
      ),
      do:
        socket
        |> update(:occasion, fn
          %{id: ^occasion_id} = occasion -> occasion
          _ -> load_occasion(occasion_id)
        end)
        |> assign(page: 0)
        |> update(:update, fn
          "init" -> "append"
          _ -> "replace"
        end)
        |> update(
          :filter,
          &(case &1 do
              nil -> occasion_id |> occasion_designs_query() |> Filter.load()
              filter -> filter
            end
            |> Filter.update(Map.get(params, "filter", %{})))
        )
        |> fetch()
        |> noreply()

  def handle_params(_, _, socket),
    do: socket |> assign(occasion: nil, filter: nil, occasions: occasions()) |> noreply()

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <div class="fixed lg:ml-[220px] w-full px-6 mx-auto max-w-screen-xl z-10 bg-white">
        <%= live_component PicselloWeb.GalleryLive.ClientMenuComponent, cart_count: @cart_count, live_action: @live_action, gallery: @gallery %>
      </div>

      <hr>
      <.step {assigns} />
    </div>
    """
  end

  # choose occasion
  defp step(%{occasion: nil} = assigns) do
    ~H"""
    <div class="px-6 pt-5 mx-auto lg:pt-10 max-w-screen-xl">
      <div class="fixed z-10 mt-16 lg:mt-8 bg-white w-full">
      <nav class="pb-7 mt-8 lg:mt-16 text-base-250">
        <ol class="flex items-center list-reset">
          <li>
            <%= live_redirect to: Routes.gallery_client_index_path(@socket, :index, @gallery.client_link_hash) do %>
              Gallery Home
            <% end %>
          </li>

          <li><.icon name="forth" class="w-2 h-2 mx-1 stroke-2"/></li>

          <li>
            <%= live_patch to: self_path(@socket, @gallery), class: "font-bold" do %>
              Choose occasion
            <% end %>
          </li>
        </ol>
      </nav>

      <h1 class="text-2xl font-extrabold sm:text-4xl">
        Choose occasion
      </h1>
      </div>

      <ul class="mt-48 pt-6 pb-16 grid grid-cols-2 lg:grid-cols-4 gap-6">
        <%= for occasion <- @occasions do %>
          <li>
            <%= live_patch to: self_path(@socket, @gallery, %{"occasion_id" => occasion.id}) do %>
              <.img_box src={occasion.preview_url} />

              <h3 class="pt-2 text-lg font-extrabold capitalize"><%= occasion.name %></h3>
            <% end %>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  defp step(%{show_filter_form: true} = assigns) do
    ~H"""
      <div class="px-6 pt-5 mx-auto lg:pt-10 max-w-screen-xl">
        <div id="filters" class="absolute top-0 left-0 z-50 w-screen min-h-screen p-8 bg-base-100">
          <button phx-click="toggle-filter-form" class="block mt-6 mb-10">
            <.icon name="close-x" class="w-5 h-5 stroke-current"/>
          </button>

          <.form for={:filter} method="get" phx-change="apply-filters" id="filter-form">
            <.ul
              filter={@filter}
              nested_list_class="mb-8 border shadow-lg border-base-200"
              button_class="flex items-center w-full py-2 text-2xl font-semibold"
              options_icon_class="peer-checked:text-base-300",
              is_mobile={true}
            />

            <.filter_option_pills filter={@filter} />

            <button type="button" phx-click="toggle-filter-form" class="flex py-2.5 mt-20 text-xl border border-base-300 justify-center items-center font-medium w-full">
              Show results
            </button>
          </.form>
        </div>
      </div>
    """
  end

  defp step(assigns) do
    ~H"""
    <div class="px-6 pt-5 mx-auto lg:pt-10 max-w-screen-xl">
      <div class="fixed sm:mt-16 lg:mt-8 pt-[32px] lg:pt-16 sm:w-[772px] lg:w-[1232px] z-10 bg-white">
        <nav class="mb-9 text-base-250">
          <ol class="flex items-center list-reset">
            <li>
              <%= live_redirect to: Routes.gallery_client_index_path(@socket, :index, @gallery.client_link_hash) do %>
                Gallery Home
              <% end %>
            </li>

            <li><.icon name="forth" class="w-2 h-2 mx-1 stroke-2"/></li>

            <li>
              <%= live_patch to: self_path(@socket, @gallery) do %>
                Choose occasion
              <% end %>
            </li>

            <li><.icon name="forth" class="w-2 h-2 mx-1 stroke-2"/></li>

            <li>
              <%= live_patch to: self_path(@socket, @gallery, %{"occasion_id" => @occasion.id}), class: "font-bold capitalize" do %>
                <%= @occasion.name %>
              <% end %>
            </li>
          </ol>
        </nav>

        <h1 class="mb-5 text-2xl font-extrabold capitalize sm:text-4xl">
          <%= @occasion.name %>
        </h1>

        <div class="flex items-end justify-between mb-7 lg:mb-2">
          <button class="flex py-2.5 px-4 text-xl border border-base-300 items-center font-medium lg:hidden" phx-click="toggle-filter-form">
            Filters

            <.icon name="funnel" class="w-4 h-4 ml-3" />
          </button>

          <.filter_navbar {assigns} />
          <p class="font-medium text-base-250">Showing <%= @filtered_count %> of <%= @total_count %> designs</p>
        </div>

        <hr class="border-base-225">

        <.form method="get" for={:pills} phx-change="apply-filters" class="pb-2 relative">
          <%= for %{id: filter_id, options: options} <- @filter, %{id: option_id, checked: true} <- options do %>
            <input type="hidden" name={"filter[#{filter_id}][]"} value={option_id}/>
          <% end %>

          <.filter_option_pills filter={@filter} />
        </.form>
      </div>

        <ul class="relative top-[250px] pb-16 pt-9 grid grid-cols-2 lg:grid-cols-4 gap-6" id="design-grid" phx-update={@update} phx-hook="InfiniteScroll" data-page={@page} data-threshold="75">
          <%= for design <- @designs do %>
            <li id={"design-#{design.id}"}>
              <button class="w-full h-full" phx-click="open-editor" value={design.id}>
                <.img_box src={design.preview_url} />

                <h3 class="pt-2 text-lg"><%= design.name %></h3>
                <p class="mt-1 text-sm text-base-250"><%= photo_range_summary(design) %></p>
              </button>
            </li>
          <% end %>
        </ul>
    </div>
    """
  end

  @impl true
  # if it fires but we are choosing an occasion
  def handle_event("load-more", _, %{assigns: %{occasion: nil}} = socket), do: noreply(socket)

  def handle_event("load-more", _, socket) do
    socket |> update(:page, &(&1 + 1)) |> assign(update: "append") |> fetch() |> noreply()
  end

  def handle_event(
        "apply-filters",
        data,
        %{assigns: %{filter: filter, gallery: gallery, occasion: %{id: occasion_id}}} = socket
      ) do
    filter_params = filter |> Filter.update(Map.get(data, "filter", %{})) |> Filter.to_params()

    socket
    |> push_patch(
      to: self_path(socket, gallery, %{occasion_id: occasion_id, filter: filter_params})
    )
    |> noreply()
  end

  def handle_event("toggle-open-filter", %{"is_unique" => _, "value" => filter_id}, socket) do
    socket
    |> update(:filter, &Enum.map(&1, fn f -> %{f | open: filter_id == f.id && f.open} end))
    |> assign(:update, "append")
    |> then(&__MODULE__.handle_event("toggle-open-filter", %{"value" => filter_id}, &1))
  end

  def handle_event("toggle-open-filter", %{"value" => filter_id}, socket) do
    socket |> update(:filter, &Filter.open(&1, filter_id)) |> noreply()
  end

  def handle_event("close-filter-dropdown", _, socket) do
    socket
    |> update(:filter, &Enum.map(&1, fn f -> %{f | open: false} end))
    |> assign(:update, "append")
    |> noreply()
  end

  def handle_event(
        "open-editor",
        %{"value" => design_id},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    %{product: product, whcc_id: design_id} =
      Repo.get(Picsello.Designs.designs_query(), design_id)

    photo = gallery |> Ecto.assoc(:photos) |> Repo.all() |> hd

    customize_and_buy_product(socket, product, photo, design: design_id)
  end

  def handle_event("toggle-filter-form", _, socket),
    do:
      socket
      |> update(:show_filter_form, &(!&1))
      |> update(:filter, &Filter.close_all/1)
      |> assign(:update, "replace")
      |> fetch()
      |> noreply()

  # for desktop view
  defp filter_navbar(assigns) do
    ~H"""
    <.form method="get" for={:filter} phx-change="apply-filters" id="filter-form" class="hidden lg:block">
      <nav class="bg-white">
        <div class="container flex flex-wrap justify-between items-center mx-auto">
          <div phx-click-away="close-filter-dropdown" class="w-auto">
            <.ul
              filter={@filter}
              main_list_class="flex rounded-lg flex-row space-x-4 text-sm font-medium bg-white"
              nested_list_class="absolute z-10 py-1 font-medium text-sm text-base-500 bg-white w-44 rounded divide-y divide-gray-100 shadow"
              button_class="flex justify-between items-center pr-2 font-black w-full text-base w-auto"
              options_icon_class="mt-2 peer-checked:text-black"
            />
          </div>
        </div>
      </nav>
    </.form>
    """
  end

  defp ul(assigns) do
    assigns = Enum.into(assigns, %{main_list_class: "", is_mobile: false})

    ~H"""
    <ul class={@main_list_class}>
      <%= for %{id: filter_id, name: name, options: options, open: open} <- @filter do %>
        <li>
          <button type="button" class={@button_class} value={filter_id} phx-value-is_unique={true} phx-click="toggle-open-filter">
            <%= name %>
            <.icon name={if open, do: "up", else: "down"} class="w-2 h-2 ml-2.5 stroke-current stroke-2"/>
          </button>
            <ul class={classes(@nested_list_class, %{"hidden" => not(open)})}>
              <.filter_options options={options} filter_id={filter_id} icon_class={@options_icon_class} />
            </ul>
            <%= if @is_mobile && !open do %>
              <hr class="mb-8">
            <% end %>
        </li>
      <% end %>
    </ul>
    """
  end

  defp filter_options(assigns) do
    assigns = Map.put_new(assigns, :icon_class, "")

    ~H"""
    <%= for %{id: option_id, checked: checked} = option <- @options, dom_id = Enum.join([@filter_id, option_id], "-") do %>
      <li>
        <input type="checkbox" id={dom_id} name={"filter[#{@filter_id}][]"} value={option_id} checked={checked} class="hidden peer"/>
        <.icon name="checkmark" class={"absolute w-8 h-4 stroke-current right-5 text-base-100 #{@icon_class}"} />

        <label for={dom_id} class="block px-5 py-3 peer-checked:bg-base-200">
          <.filter_option_label option={option} />
        </label>
      </li>
    <% end %>
    """
  end

  defp filter_option_label(assigns) do
    ~H"""
    <div class="flex items-center leading-snug capitalize">
      <%= case @option do %>
        <% %{name: name, swatch: {r,g,b}} -> %>
            <div style={"background-color:rgb(#{r},#{g},#{b})"} class="w-4 h-4 mr-2"></div>
            <%= name %>

          <% %{name: name} -> %> <%= name %>
      <% end %>
    </div>
    """
  end

  defp filter_option_pills(assigns) do
    ~H"""
      <ul class="flex flex-wrap w-full" {testid("pills")}>
        <%= for %{id: filter_id, options: options} <- @filter, %{checked: true, id: option_id} = option <- options do %>
          <li>
            <label class="mx-4 mt-7 first:ml-0 py-2.5 px-4 text-xl border border-base-250 items-center justify-center font-medium text-base-250 flex">
              <input type="checkbox" class="hidden" value={option_id} name={"filter[remove][#{filter_id}][]"}/>
              <.filter_option_label option={option} />

              <.icon name="close-x" class="w-3 h-3 ml-3 stroke-current stroke-[5px]" />
            </label>
          </li>
        <% end %>
      </ul>
    """
  end

  defp photo_range_summary(%{photo_slots: slots}) do
    slots
    |> slot_ranges()
    |> case do
      [] ->
        ""

      [1..1] ->
        "1 photo"

      ranges ->
        Enum.join(
          for %{first: first, last: last} <- ranges do
            case last - first do
              0 -> last
              1 -> Enum.join([first, last], ", ")
              _ -> Enum.join([first, last], "-")
            end
          end,
          ", "
        ) <> " photos"
    end
  end

  defp slot_ranges(slots),
    do:
      slots
      |> combinations()
      |> Enum.map(&Enum.sum/1)
      |> Enum.uniq()
      |> Enum.sort()
      |> ranges()

  def combinations([values]), do: Enum.map(values, &[&1])

  def combinations([values | tail]),
    do: for(combos <- combinations(tail), value <- values, do: [value | combos])

  def ranges([head | tail]) do
    for n <- tail, reduce: [head..head] do
      [%{last: last} = range | rest] when n == last + 1 -> [range.first..n | rest]
      [range | rest] -> [n..n | [range | rest]]
    end
    |> Enum.reverse()
  end

  def ranges([]), do: []

  defp img_box(assigns) do
    ~H"""
      <div class="aspect-h-1 aspect-w-1">
        <div class="bg-gradient-to-bl from-[#f5f6f7] to-[#ededed] flex flex-col justify-center">
          <img class="object-scale-down min-h-0 p-6 drop-shadow-md" src={@src}/>
        </div>
      </div>
    """
  end

  defp self_path(socket, gallery, params \\ %{}),
    do:
      Routes.gallery_card_editor_path(
        socket,
        :index,
        gallery.client_link_hash,
        params
      )

  def fetch(%{assigns: %{page: page, occasion: occasion, filter: filter}} = socket) do
    occasion_designs = occasion_designs_query(occasion)
    total_count = Repo.aggregate(occasion_designs, :count, :id)

    filtered_designs = Filter.query(occasion_designs, filter)

    filtered_count = Repo.aggregate(filtered_designs, :count, :id)

    assign(socket,
      designs: load_designs(filtered_designs, page),
      total_count: total_count,
      filtered_count: filtered_count
    )
  end

  def load_designs(filtered_designs, page),
    do:
      from(design in Picsello.Designs.designs_query(filtered_designs),
        limit: @per_page,
        offset: ^page * @per_page
      )
      |> Repo.all()
end
