defmodule PicselloWeb.Live.Profile do
  @moduledoc "photographers public profile"
  use PicselloWeb, live_view: [layout: "profile"]
  alias Picsello.Profiles

  @impl true
  def mount(%{"organization_slug" => slug}, session, socket) do
    socket |> assign_defaults(session) |> assign_organization(slug) |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-grow border-t-8 border-b-8" style={"border-color: #{@color}"}>
      <div class="flex px-48 mt-20 mb-32 center-container">
        <div class="mr-10">
          <h1 class="text-6xl font-bold"><%= @organization.name %></h1>

          <h2 class="mt-12 text-lg font-bold">What we offer:</h2>
          <div class="w-1/4 h-2" style={"background-color: #{@color}"}></div>

          <div class="w-min">
            <%= for job_type <- @organization.user.onboarding.job_types do %>
              <div class="flex my-4 p-4 items-center font-semibold rounded-lg bg-[#fafafa]">
                <span style={"color: #{@color};"}>
                  <.icon name={job_type} class="mr-6 fill-current w-9 h-9" />
                </span>

                <span class="whitespace-nowrap"><%= dyn_gettext job_type %></span>
              </div>
            <% end %>
          </div>

          <%= if @website do %>
            <a href={@website} class="mb-2 underline underline-offset-1" href="#">See our full portfolio</a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp assign_organization(socket, slug) do
    %{user: %{onboarding: onboarding}} = organization = Profiles.find_organization_by(slug: slug)

    assign(socket,
      organization: organization,
      color: onboarding.color,
      website: onboarding.website
    )
  end
end
