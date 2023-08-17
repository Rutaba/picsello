defmodule PicselloWeb.PackageLive.PackagesSearchComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  import Ecto.Query
  import Phoenix.Component

  alias Picsello.{
    Repo,
    Package
  }

  @impl true
  def update(assigns, socket) do
    socket
    |> assign_new(:package_type, fn -> "all" end)
    |> assign_new(:sort_by, fn -> "name" end)
    |> assign_new(:sort_direction, fn -> "desc" end)
    |> assign_new(:search_phrase_packages, fn -> nil end)
    |> assign(assigns)
    |> assign_job_types()
    |> assign_packages()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-between items-center px-1.5 md:flex-row mb-10 gap-6">
      <div class="relative flex lg:w-2/3 md:w-1/2 w-full md:mt-6">
        <a href='#' class="absolute top-0 bottom-0 flex flex-row items-center justify-center overflow-hidden text-xs text-gray-400 left-2">
          <%= if @search_phrase_packages do %>
            <span phx-click="clear-search" phx-target={@myself} class="cursor-pointer">
              <.icon name="close-x" class="w-4 ml-1 fill-current stroke-current stroke-2 close-icon text-blue-planning-300" />
            </span>
          <% else %>
            <.icon name="search" class="w-4 ml-1 fill-current" />
          <% end %>
        </a>
          <input type="text" class="form-control w-full text-input indent-6" id="search_phrase_input" name="search_phrase" value={"#{@search_phrase_packages}"} phx-debounce="100" phx-change= "search" phx-target={@myself} spellcheck="false" placeholder="Search packages..." />
      </div>

      <div class="flex flex-wrap grow md:flex-nowrap gap-3 items-center md:w-1/3 w-full">
        <.select_dropdown title="Photography Type" selected_option={@package_type} id="type" options_list={@job_types} target={@myself}/>
        <.select_dropdown title="Sort" id="sort" selected_option={@sort_by} options_list={packages_sort_options()} sort_direction={@sort_direction} target={@myself}/>
      </div>
    </div>
    """
  end

  def select_dropdown(assigns) do
    ~H"""
    <div class="flex grow">
      <div id={@id} class={"relative w-full mt-3 md:mt-0"} data-offset-y="10" phx-hook="Select">
        <div>
          <h4 class="font-extrabold text-sm mb-1"><%= @title %></h4>
        </div>
        <div class="flex w-full">
          <div class="w-full">
            <div class={"flex flex-row items-center border #{@title != "Sort" && "rounded-lg"} p-3 #{@title == "Sort" && "rounded-l-lg"}"}>
                <span class="flex-shrink-0"><%= String.capitalize(String.replace(@selected_option, "_", " ")) %></span>
                <.icon name="down" class="flex-shrink-0 w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 open-icon" />
                <.icon name="up" class="flex-shrink-0 hidden w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 close-icon" />
            </div>
            <ul class="absolute z-30 hidden w-full md:w-32 mt-2 bg-white toggle rounded-md popover-content border shadow-lg">
              <%= for option <- @options_list do %>
                <li id={option.id} target-class="toggle-it" parent-class="toggle" toggle-type="selected-active" phx-hook="ToggleSiblings"
                class="flex items-center py-1.5 hover:bg-blue-planning-100 hover:rounded-md">
                  <button id={option.id} class="album-select" phx-click={"apply-filter-#{@id}"} phx-target={@target} phx-value-option={option.id}><%= option.title %></button>
                  <%= if option.id == @selected_option do %>
                    <.icon name="tick" class="w-6 h-5 mr-1 toggle-it text-blue-planning-300" />
                  <% end %>
                </li>
              <% end %>
            </ul>
          </div>
          <%= if @title == "Sort" do%>
          <div class="items-center flex border rounded-r-lg border-grey p-2">
            <button phx-click="switch_sort" phx-target={@target}>
              <%= if @sort_direction == "asc" do%>
                <.icon name="sort-vector" {testid("edit-link-button")} class="blue-planning-300 w-5 h-5" />
              <% else%>
                <.icon name="sort-vector-2" {testid("edit-link-button")} class="blue-planning-300 w-5 h-5" />
              <% end %>
            </button>
          </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def packages_search_component(assigns) do
    ~H"""
      <.live_component id={assigns[:id]} {assigns} module={__MODULE__} />
    """
  end

  @impl true
  def handle_event(
        "apply-filter-type",
        %{"option" => type},
        socket
      ) do
    socket
    |> assign(:package_type, type)
    |> assign_packages()
    |> noreply()
  end

  @impl true
  def handle_event(
        "apply-filter-sort",
        %{"option" => sort_by},
        socket
      ) do
    socket
    |> assign(:sort_by, sort_by)
    |> assign_packages()
    |> noreply()
  end

  @impl true
  def handle_event(
        "search",
        %{"search_phrase" => search_phrase},
        socket
      ) do
    socket
    |> assign(:search_phrase_packages, search_phrase)
    |> assign_packages()
    |> noreply()
  end

  @impl true
  def handle_event("switch_sort", _, %{assigns: %{sort_direction: sort_direction}} = socket) do
    direction = if sort_direction == "asc", do: "desc", else: "asc"

    socket
    |> assign(:sort_direction, direction)
    |> assign_packages()
    |> noreply()
  end

  @impl true
  def handle_event("clear-search", _, socket) do
    socket
    |> assign(:search_phrase_packages, nil)
    |> assign_packages()
    |> noreply()
  end

  defp assign_packages(
         %{assigns: %{current_user: %{organization: organization}, package_type: "all"} = assigns} =
           socket
       ) do
    filters = assigns |> Map.take([:sort_by, :sort_direction, :search_phrase_packages])

    package_templates =
      Package.templates_for_organization_query(organization.id)
      |> apply_filters(filters)

    send(socket.root_pid, {:update_templates, %{templates: package_templates}})
    socket |> assign(:templates, package_templates)
  end

  defp assign_packages(
         %{assigns: %{current_user: current_user, package_type: type} = assigns} = socket
       ) do
    filters = assigns |> Map.take([:sort_by, :sort_direction, :search_phrase_packages])
    package_templates = current_user |> Package.templates_for_user(type) |> apply_filters(filters)
    send(socket.root_pid, {:update_templates, %{templates: package_templates}})
    socket |> assign(:templates, package_templates)
  end

  defp apply_filters(query, opts) do
    query
    |> where([package], ^filters_where(opts))
    |> Repo.all()
    |> sort_packages_templates(opts)
  end

  defp sort_packages_templates(templates, %{sort_by: "name", sort_direction: sort_direction}) do
    sort_direction = String.to_atom(sort_direction)
    templates |> Enum.sort_by(& &1.name, sort_direction)
  end

  defp sort_packages_templates(templates, %{sort_by: "price", sort_direction: sort_direction}) do
    sort_direction = String.to_atom(sort_direction)
    templates |> Enum.sort_by(&(&1 |> Package.price()), sort_direction)
  end

  defp filters_where(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {:search_phrase_packages, nil}, dynamic ->
        dynamic

      {:search_phrase_packages, search_phrase}, dynamic ->
        search_phrase = "%#{search_phrase}%"

        dynamic(
          [package],
          ^dynamic and
            ilike(package.name, ^search_phrase)
        )

      {_, _}, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  defp assign_job_types(%{assigns: %{current_user: current_user, job_types: job_types}} = socket) do
    current_user =
      current_user |> Repo.preload([organization: :organization_job_types], force: true)

    job_types =
      job_types
      |> Enum.map(fn j ->
        %{title: String.capitalize(j), id: j}
      end)

    socket
    |> assign(:current_user, current_user)
    |> assign(
      :job_types,
      [%{title: "All", id: "all"} | job_types]
    )
  end

  defp packages_sort_options() do
    [
      %{title: "Name", id: "name", column: "name", direction: "desc"},
      %{title: "Price", id: "price", column: "price", direction: "desc"}
    ]
  end
end
