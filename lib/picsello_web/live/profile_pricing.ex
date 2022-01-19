defmodule PicselloWeb.Live.ProfilePricing do
  @moduledoc "photographers public profile pricing"
  use PicselloWeb, live_view: [layout: "profile"]
  alias Picsello.{Profiles, Packages}

  import PicselloWeb.Live.Profile.Shared,
    only: [assign_organization_by_slug: 2, photographer_logo: 1, profile_footer: 1]

  @impl true
  def mount(%{"organization_slug" => slug} = params, session, socket) do
    edit = Map.get(params, "edit")

    socket
    |> assign_defaults(session)
    |> assign_organization_by_slug(slug)
    |> assign(:edit, edit == "true")
    |> ok()
  end

  @impl true
  def handle_params(%{"job_type" => job_type}, _, socket) do
    socket
    |> assign_job_type(job_type)
    |> noreply()
  end

  @impl true
  def handle_params(%{}, _, socket) do
    socket
    |> assign_initial_job_type()
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="grid grid-cols-3 center-container p-6">
        <.live_link to={if @edit, do: Routes.profile_settings_path(@socket, :edit), else: Routes.profile_path(@socket, :index, @organization.slug)} class="flex items-center">
          <.icon name="back" class="w-2 h-3 stroke-current mr-4" />
          Back
        </.live_link>
        <div class="hidden md:flex justify-center">
          <.photographer_logo color={@color} photographer={@photographer} />
        </div>
        <div class="md:hidden col-span-2 flex justify-end">
          <a class="btn-primary text-center py-2"href="#contact">Let's chat</a>
        </div>
      </div>

      <div class="bg-[#fafafa] flex flex-col items-center py-12">
        <h2 class="uppercase font-semibold text-xl" style={"color: #{@color}; letter-spacing: 0.3em;"}>Pricing</h2>
        <h1 class="text-5xl mt-2 font-bold text-center lg:text-6xl md:text-left"><%= @organization.name %></h1>
      </div>

      <div class="center-container">
        <h3 class="px-6 font-bold text-2xl my-8" style={"color: #{@color};"}>Photography package types</h3>
        <.job_types_nav socket={@socket} job_types={@job_types} organization={@organization} current_job_type={@job_type} color={@color} />

        <div class="bg-[#fafafa] px-6 md:px-24 pb-14">
          <%= for package <- @packages do %>
            <.package_detail name={package.name} price={Packages.price(package)} description={package.description} download_count={package.download_count} />
          <% end %>
        </div>
      </div>

      <.profile_footer color={@color} photographer={@photographer} organization={@organization} />
    </div>
    """
  end

  defp job_types_nav(assigns) do
    ~H"""
    <ul class="flex font-bold mt-10 text-xl px-6 overflow-auto">
      <%= for job_type <- @job_types do %>
        <% active = job_type == @current_job_type %>
        <li id={"nav-#{job_type}"} {if active, do: %{phx_hook: "ScrollIntoView"}, else: %{}} class="border-b-8 mr-6 px-4 flex whitespace-nowrap items-center" style={"border-color: #{if active, do: @color, else: "white"}"}>
          <%= if active do %>
            <.icon name={job_type} class="fill-current w-6 h-6" />
          <% end %>
          <%= live_patch to: Routes.profile_pricing_job_type_path(@socket, :index, @organization.slug, job_type), replace: false do %>
            <div class="px-3 pb-2">
              <%= dyn_gettext job_type %>
            </div>
          <% end %>
        </li>
      <% end %>
    </ul>
    """
  end

  defp package_detail(assigns) do
    ~H"""
    <div class="flex justify-between font-bold text-xl pt-14">
      <div><%= @name %></div>
      <div><%= Money.to_string(@price, fractional_unit: false) %></div>
    </div>

    <div>
      <dl class="flex mt-4">
        <dt class="underline mr-2">Description:</dt>
        <dd><%= @description %></dd>
      </dl>
      <dl class="flex mt-4">
        <dt class="underline mr-2">Included:</dt>
        <dd><%= ngettext "1 photo download", "%{count} photo downloads", @download_count %></dd>
      </dl>
    </div>
    """
  end

  defp assign_job_type(%{assigns: %{organization: organization}} = socket, job_type) do
    packages =
      Packages.templates_for_organization(organization)
      |> Enum.filter(&(&1.job_type == job_type))
      |> Enum.sort_by(&(-Packages.price(&1).amount))

    socket |> assign(job_type: job_type, packages: packages)
  end

  defp assign_initial_job_type(%{assigns: %{job_types: [job_type | _]}} = socket) do
    assign_job_type(socket, job_type)
  end
end
