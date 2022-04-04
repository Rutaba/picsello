defmodule PicselloWeb.Live.Profile.Embed do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "profile"]
  alias Picsello.{Packages, Subscriptions}

  import PicselloWeb.Live.Profile.Shared,
    only: [
      assign_organization_by_slug: 2
    ]

  @impl true
  def mount(%{"organization_slug" => slug}, session, socket) do
    socket
    |> assign(:edit, false)
    |> assign(:uploads, nil)
    |> assign_defaults(session)
    |> assign_organization_by_slug(slug)
    |> assign_job_type_packages()
    |> maybe_redirect_slug(slug)
    |> check_active_subscription()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="client-app">
      <%= live_component PicselloWeb.Live.Profile.ContactFormComponent, id: "contact-component", organization: @organization, color: @color, job_types: @job_types, job_type: @job_type %>
    </div>
    """
  end

  defp assign_job_type_packages(%{assigns: %{organization: organization}} = socket) do
    packages =
      Packages.templates_for_organization(organization)
      |> Enum.group_by(& &1.job_type)

    socket |> assign(:job_type_packages, packages) |> assign(:job_type, nil)
  end

  defp maybe_redirect_slug(%{assigns: %{organization: organization}} = socket, current_slug) do
    if current_slug != organization.slug do
      push_redirect(socket, to: Routes.profile_path(socket, :index, organization.slug))
    else
      socket
    end
  end

  defp check_active_subscription(%{assigns: %{organization: organization}} = socket) do
    Subscriptions.ensure_active_subscription!(organization.user)

    socket
  end
end
