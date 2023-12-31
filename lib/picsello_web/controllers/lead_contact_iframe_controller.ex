defmodule PicselloWeb.LeadContactIframeController do
  use PicselloWeb, :controller

  alias Picsello.{Profiles}

  def index(conn, params) do
    conn
    |> assign_organization_by_slug(params)
    |> assign_changeset
    |> render("index.html")
  end

  def create(conn, %{"organization_slug" => organization_slug, "contact" => contact} = params) do
    organization = Profiles.find_organization_by_slug(slug: organization_slug)

    case Profiles.handle_contact(organization, contact, PicselloWeb.Helpers) do
      {:ok, _client} ->
        conn
        |> render("thank-you.html")

      {:error, changeset} ->
        conn
        |> assign_organization_by_slug(params)
        |> assign(:changeset, changeset)
        |> put_flash(:error, "Form has errors")
        |> render("index.html")
    end
  end

  def create(conn, params) do
    conn
    |> assign_organization_by_slug(params)
    |> assign_changeset
    |> put_flash(:error, "Form is empty")
    |> render("index.html")
  end

  defp assign_organization_by_slug(conn, %{"organization_slug" => slug}) do
    organization = Profiles.find_organization_by_slug(slug: slug)

    conn
    |> assign(:job_types, Profiles.public_job_types(organization.organization_job_types))
    |> assign(:organization, organization)
  end

  defp assign_changeset(conn) do
    conn
    |> assign(
      :changeset,
      Profiles.contact_changeset()
    )
  end
end
