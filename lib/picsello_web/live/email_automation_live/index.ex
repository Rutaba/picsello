defmodule PicselloWeb.Live.EmailAutomations.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import Picsello.Onboardings, only: [save_intro_state: 3]
  alias Ecto.Changeset
  import PicselloWeb.LiveHelpers

  alias Picsello.{
    Repo,
    Profiles
  }

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Automations")
    |> assign(type: "Default")
    |> assign(:collapsed_sections, [])
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

  def handle_event(
        "assign_templates_by_type",
        %{"type" => type},
         socket
      ) do
    socket
    |> assign(:type, type)
    |> noreply()
  end

  def handle_event(
      "toggle-section",
      %{"section_id" => section_id},
      %{assigns: %{collapsed_sections: collapsed_sections}} = socket
    ) do
  collapsed_sections =
    if Enum.member?(collapsed_sections, section_id) do
      Enum.filter(collapsed_sections, &(&1 != section_id))
    else
      collapsed_sections ++ [section_id]
    end

    socket
    |> assign(:collapsed_sections, collapsed_sections)
    |> noreply()
  end
end
