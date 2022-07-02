defmodule PicselloWeb.Live.Profile.Shared do
  @moduledoc """
  functions used by editing profile components
  """
  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  use Phoenix.Component
  alias Picsello.Profiles

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset()
    |> ok()
  end

  def handle_event("validate", %{"organization" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  def handle_event(
        "save",
        %{"organization" => params},
        %{assigns: %{organization: organization}} = socket
      ) do
    case Profiles.update_organization_profile(organization, params) do
      {:ok, organization} ->
        send(socket.parent_pid, {:update, organization})
        socket |> close_modal() |> noreply()

      {:error, _} ->
        socket |> noreply()
    end
  end

  def open(%{assigns: assigns} = socket, module),
    do:
      open_modal(
        socket,
        module,
        %{assigns: assigns |> Map.drop([:flash])}
      )

  def assign_changeset(
        %{assigns: %{organization: organization}} = socket,
        params \\ %{},
        action \\ :validate
      ) do
    changeset =
      organization
      |> Profiles.edit_organization_profile_changeset(params)
      |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  def assign_organization_by_slug(socket, slug) do
    organization = Profiles.find_organization_by(slug: slug)
    assign_organization(socket, organization)
  end

  def assign_organization(socket, organization) do
    %{profile: profile, user: user, brand_links: brand_links} = organization

    assign(socket,
      organization: organization,
      color: profile.color,
      description: profile.description,
      job_types_description: profile.job_types_description,
      website: get_website_link(brand_links),
      photographer: user,
      job_types: profile.job_types,
      url: Profiles.public_url(organization)
    )
  end

  defp get_website_link(brand_links),
    do: brand_links |> Enum.filter(&(&1.link_id == "website")) |> List.first() |> Map.get(:link)

  def photographer_logo(assigns) do
    ~H"""
      <%= case Profiles.logo_url(@organization) do %>
        <% nil -> %> <h1 class="pt-3 text-3xl font-bold font-client text-base-300"><%= @organization.name %></h1>
        <% url -> %> <img class="h-16" src={url} />
      <% end %>
    """
  end

  def profile_footer(assigns) do
    ~H"""
     <footer class="px-6 md:px-16 mt-10 center-container">
      <div class="flex justify-center py-8 md:justify-start md:py-14"><.photographer_logo {assigns} /></div>

      <div class="flex flex-col items-center justify-start pt-6 mb-8 border-t md:flex-row md:justify-between border-base-250 text-base-300 opacity-30">
        <span>© <%= Date.utc_today().year %> <%= @organization.name %></span>

        <span class="mt-2 md:mt-0">Powered By <a href="https://www.picsello.com/?utm_source=app&utm_medium=link&utm_campaign=public_profile&utm_contentType=landing_page&utm_content=footer_link&utm_audience=existing_user" target="_blank">Picsello</a></span>
      </div>
    </footer>
    """
  end
end
