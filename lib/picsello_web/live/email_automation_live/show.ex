defmodule PicselloWeb.Live.EmailAutomations.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import PicselloWeb.LiveHelpers
  import PicselloWeb.EmailAutomationLive.Shared, only: [assign_automation_pipelines: 1]

  alias Picsello.{
    Galleries,
    Jobs,
    EmailAutomation,
    Repo
  }

  def mount(%{"id" => id} = _params, _session, socket) do
    socket
    |> assign(:job_id, to_integer(id))
    |> assign_email_schedules()
    |> assign(:collapsed_sections, [])
    |> assign_job_types()
    |> assign_automation_pipelines()
    |> ok()
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
  def handle_event("confirm-stop-email", %{}, socket) do
    email_id = "1"
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      title: "Are you sure you want to {stop/send} this email?",
      subtitle: "Stop this email and your client will get the next email in the sequence. To stop the full automation sequence from sending, you will need to Stop each email individually.",
      confirm_event: "stop-email-schedule-"<> email_id,
      confirm_label: "Yes, stop email",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> noreply()
  end

  @impl true
  def handle_event("send-email-now", _param, socket) do
    socket
    |> assign_email_schedules()
    |> noreply()
  end

  @impl true
  def handle_event("edit-email", _param, socket) do
    socket
    |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "stop-email-schedule_" <> id}, socket) do
    _id = String.to_integer(id)

    socket
    |> assign_email_schedules()
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

  defp assign_email_schedules(%{assigns: %{job_id: job_id}} = socket) do
    galleries = Galleries.get_galleries_by_job_id(job_id) |> Enum.map(&(&1.id))

    IO.inspect(galleries, charlists: :as_lists)
    job = job_id |> Jobs.get_job_by_id()

    gallery_emails = EmailAutomation.get_emails_schedules_galleries(galleries)
    jobs_emails = EmailAutomation.get_emails_schedules_jobs(job_id)
    email_schedules = jobs_emails ++ gallery_emails

    socket
    |> assign(:type, job.type)
    |> assign(email_schedules: email_schedules)
  end

  defp valid_type?(%{assigns: %{selected_job_type: nil}}), do: false
  defp valid_type?(%{assigns: %{selected_job_type: _type}}), do: true
end
