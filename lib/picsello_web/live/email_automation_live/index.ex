defmodule PicselloWeb.Live.EmailAutomations.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import PicselloWeb.LiveHelpers

  alias Picsello.{
    EmailAutomation,
    Repo
  }

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Automations")
    |> assign(:collapsed_sections, [])
    |> default_assigns()
    |> ok()
  end

  defp default_assigns(socket) do
    socket
    |> assign_job_types()
    |> assign_automation_pipelines()
  end

  defp assign_job_types(%{assigns: %{current_user: current_user}} = socket) do
    current_user =
      current_user |> Repo.preload([organization: :organization_job_types], force: true)

    job_types =
      current_user.organization.organization_job_types
      |> Enum.filter(fn job_type -> job_type.show_on_business? end)

    selected_job_type = job_types |> List.first()

    socket
    |> assign(:current_user, current_user)
    |> assign(:job_types, job_types)
    |> assign(:selected_job_type, selected_job_type)
  end

  def assign_automation_pipelines(
        %{assigns: %{current_user: current_user, selected_job_type: selected_job_type}} = socket
      ) do
    automation_pipelines =
      EmailAutomation.get_all_pipelines_emails(current_user.organization_id, selected_job_type.id)
      |> assign_category_pipeline_count()

    socket |> assign(:automation_pipelines, automation_pipelines)
  end

  defp assign_category_pipeline_count(automation_pipelines) do
    automation_pipelines
    |> Enum.map(fn %{subcategories: subcategories} = category ->
      total_pipelines =
        subcategories
        |> Enum.reduce(0, fn subcategory, acc ->
          acc + length(subcategory.pipelines)
        end)

      Map.put(category, :total_category_pipelines, total_pipelines)
    end)
  end

  @impl true
  def handle_event(
        "assign_templates_by_type",
        %{"id" => id},
        %{assigns: %{job_types: job_types}} = socket
      ) do
    id = to_integer(id)

    selected_job_type = job_types |> Enum.filter(fn x -> x.id == id end) |> List.first()

    socket
    |> assign(:selected_job_type, selected_job_type)
    |> assign_automation_pipelines()
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-email-popup",
        _,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> open_modal(PicselloWeb.EmailAutomationLive.EditEmailComponent, %{current_user: current_user})
    |> noreply()
  end

  @impl true
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

  @impl true
  def handle_info({:update_automation, _}, socket) do
    socket
    |> put_flash(:success, "Email signature saved")
    |> noreply()
  end
end
