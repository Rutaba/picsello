defmodule PicselloWeb.Live.EmailAutomations.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  alias Picsello.{
    Repo,
    Profiles
  }

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Automations")
    |> default_assigns()
    |> ok()
  end

  defp default_assigns(socket) do
    socket
    |> assign_job_types()
  end

  defp assign_job_types(%{assigns: %{current_user: current_user}} = socket) do
    current_user =
      current_user |> Repo.preload([organization: :organization_job_types], force: true)

    socket
    |> assign(:current_user, current_user)
    |> assign(
      :job_types,
      Profiles.enabled_job_types(current_user.organization.organization_job_types)
    )
  end
end
