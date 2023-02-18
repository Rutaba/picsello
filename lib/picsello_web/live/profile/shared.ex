defmodule PicselloWeb.Live.Profile.Shared do
  @moduledoc """
  functions used by editing profile components
  """
  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  use Phoenix.Component
  alias Picsello.{Profiles, BrandLinks, BrandLink}

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_brand_links()
    |> assign_changeset()
    |> ok()
  end

  def handle_event("validate", %{"organization" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  def handle_event(
        "save",
        %{"organization" => %{"brand_links" => %{"0" => brand_link_params}}},
        %{assigns: %{organization: organization}} = socket
      ) do
    case handle_brand_link(organization, brand_link_params) do
      [] ->
        socket |> noreply()

      brand_links ->
        organization = Map.put(organization, :brand_links, brand_links)

        send(socket.parent_pid, {:update, organization})

        socket |> close_modal() |> noreply()
    end
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

  def assign_organization_by_slug_on_profile_disabled(socket, slug) do
    organization = Profiles.find_organization_by_slug(slug: slug)
    assign_organization(socket, organization)
  end

  def assign_organization(socket, organization) do
    %{
      profile: profile,
      user: user,
      brand_links: brand_links,
      organization_job_types: organization_job_types
    } = organization

    assign(socket,
      organization: organization,
      color: profile.color,
      description: profile.description,
      job_types_description: profile.job_types_description,
      website: get_website_link(brand_links),
      photographer: user,
      job_types: Profiles.public_job_types(organization_job_types),
      url: Profiles.public_url(organization)
    )
  end

  defp handle_brand_link(%{brand_links: [brand_link]}, params) do
    changeset = BrandLink.brand_link_changeset(brand_link, params)
    link = changeset |> Ecto.Changeset.get_field(:link)

    cond do
      !is_nil(link) && is_nil(brand_link.id) ->
        brand_link |> upsert_brand_link(link, [:id])

      changeset.valid? && !is_nil(link) ->
        brand_link |> upsert_brand_link(link)

      true ->
        delete_brand_link(brand_link)
    end
  end

  defp delete_brand_link(brand_link) do
    case BrandLinks.delete_brand_link(brand_link) do
      {:ok, _} -> Map.put(brand_link, :link, nil) |> List.wrap()
      _ -> []
    end
  end

  defp upsert_brand_link(brand_link, link, params \\ []) do
    brand_link
    |> Map.put(:link, link)
    |> Map.from_struct()
    |> Map.drop(params ++ [:__meta__, :organization])
    |> List.wrap()
    |> BrandLinks.upsert_brand_links()
    |> Enum.filter(&(&1.link_id == "website"))
  end

  defp assign_brand_links(%{assigns: %{organization: organization}} = socket) do
    organization =
      case organization do
        %{brand_links: []} = organization ->
          Map.put(organization, :brand_links, [
            %BrandLink{
              title: "Website",
              link_id: "website",
              organization_id: organization.id
            }
          ])

        organization ->
          organization
      end

    socket
    |> assign(:organization, organization)
  end

  defp get_website_link([]), do: nil
  defp get_website_link(nil), do: nil

  defp get_website_link(brand_links) do
    website = Enum.find(brand_links, &(&1.link_id == "website"))
    if website, do: website |> Map.get(:link), else: nil
  end

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
    <footer class="mt-auto pt-10 center-container">
      <div class="flex flex-col md:flex-row">
        <div class="flex justify-center py-8 md:justify-start md:py-14"><.photographer_logo {assigns} /></div>
        <div class="flex items-center justify-center md:ml-auto flex-wrap">
          <%= for %{link: link, link_id: link_id, show_on_profile?: true, active?: true} <- Profiles.get_brand_links_by_organization(@organization) do %>
            <div {testid("marketing-links")} class="flex items-center mb-4">
              <a href={link} target="_blank" rel="noopener noreferrer">
                <div class="flex items-center justify-center w-10 h-10 mx-1 rounded-full flex-shrink-0 bg-base-200 p-3">
                  <.icon name={get_brand_link_icon(link_id)} />
                </div>
              </a>
            </div>
          <% end %>
        </div>
      </div>
      <div class="flex flex-col items-center justify-start pt-6 mb-8 border-t md:flex-row md:justify-between border-base-250 text-base-300 opacity-30">
        <span>© <%= Date.utc_today().year %> <%= @organization.name %></span>

        <span class="mt-2 md:mt-0">Powered By <a href="https://www.picsello.com/?utm_source=app&utm_medium=link&utm_campaign=public_profile&utm_contentType=landing_page&utm_content=footer_link&utm_audience=existing_user" target="_blank">Picsello</a></span>
      </div>
    </footer>
    """
  end
end
