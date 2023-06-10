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
    |> assign_job_types()
    |> assign_automation_pipelines()
    |> ok()
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
