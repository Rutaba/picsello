defmodule PicselloWeb.Live.EmailAutomations.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import PicselloWeb.LiveHelpers
  import PicselloWeb.EmailAutomationLive.Shared, only: [assign_automation_pipelines: 1]

  alias Picsello.{
    Repo
  }

  def mount(%{"type" => type} = _params, _session, socket) do
    socket
    |> assign(:type, String.downcase(type))
    |> assign(:collapsed_sections, [])
    |> assign_job_types()
    |> assign_automation_pipelines()
    |> ok()
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

  def handle_event("confirm-stop-email", %{}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      title: "Are you sure you want to {stop/send} this email?",
      subtitle: "Stop this email and your client will get the next email in the sequence. To stop the full automation sequence from sending, you will need to Stop each email individually.",
      confirm_event: "",
      confirm_label: "Yes, stop email",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> noreply()
  end

  defp assign_job_types(%{assigns: %{current_user: current_user, type: type}} = socket) do
    current_user =
      current_user
      |> Repo.preload([organization: [organization_job_types: :jobtype]], force: true)

    job_types =
      current_user.organization.organization_job_types
      |> Enum.sort_by(& &1.jobtype.position)

    selected_job_type = job_types |> Enum.filter(fn x -> x.job_type == type end) |> List.first()

    socket
    |> assign(:current_user, current_user)
    |> assign(:job_types, job_types)
    |> assign(:selected_job_type, selected_job_type)
  end

  defp valid_type?(%{assigns: %{selected_job_type: nil}}), do: false
  defp valid_type?(%{assigns: %{selected_job_type: _type}}), do: true
end
