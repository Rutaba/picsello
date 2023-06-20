defmodule PicselloWeb.Live.EmailAutomations.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import PicselloWeb.LiveHelpers
  import PicselloWeb.EmailAutomationLive.Shared, only: [get_pipline: 1, explode_hours: 1]
  import PicselloWeb.Gettext, only: [ngettext: 3]

  alias Picsello.{
    Galleries,
    Jobs,
    EmailAutomation,
    EmailAutomation.EmailSchedule,
    Notifiers.ClientNotifier,
    Orders,
    Galleries,
    Repo
  }

  def mount(%{"id" => id} = _params, _session, socket) do
    socket
    |> assign(:job_id, to_integer(id))
    |> assign_email_schedules()
    |> assign(:collapsed_sections, [])
    |> assign_job_types()
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
  def handle_event("confirm-stop-email", %{"email_id" => email_id}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      title: "Are you sure you want to {stop/send} this email?",
      subtitle:
        "Stop this email and your client will get the next email in the sequence. To stop the full automation sequence from sending, you will need to Stop each email individually.",
      confirm_event: "stop-email-schedule-" <> email_id,
      confirm_label: "Yes, stop email",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> noreply()
  end

  @impl true
  def handle_event("send-email-now", %{"email_id" => id, "pipeline_id" => pipeline_id},  %{assigns: %{job_id: job_id}} = socket) do
    id = to_integer(id)
    pipeline_id = to_integer(pipeline_id)

    email = EmailAutomation.get_email_schedule_by_id(id) |> Repo.preload(email_automation_pipeline: [:email_automation_category])
    pipeline = get_pipline(pipeline_id)

    job = Jobs.get_job_by_id(job_id) |> Repo.preload([:payment_schedules, :job_status, client: :organization])

    case EmailAutomation.send_now_email(pipeline.email_automation_category.type, email, job, pipeline.state) do
      {:ok, _} ->  socket |> put_flash(:success, "Email Sent Successfully")
      _ -> socket |> put_flash(:success, "Error in Sending Email")
    end
    |> assign_email_schedules()
    |> noreply()
  end

  @impl true
  def handle_event("edit-email", %{"email_id" => id, "pipeline_id" => pipeline_id}, socket) do
    id = to_integer(id)
    pipeline_id = to_integer(pipeline_id)

    _param = %{
      pipeline: get_pipline(pipeline_id),
      email_id: id,
      email: EmailAutomation.get_email_schedule_by_id(id)
    }

    socket
    |> put_flash(:success, "Email Edited")
    |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "stop-email-schedule-" <> id}, socket) do
    id = String.to_integer(id)

    case EmailSchedule.update_email_schedule(id, %{is_stopped: true}) do
      {:ok, _} -> socket |> put_flash(:success, "Email Stopped Successfully")
      _ -> socket |> put_flash(:error, "Error in Updating Email")
    end
    |> close_modal()
    |> assign_email_schedules()
    |> noreply()
  end

  defp pipeline_section(assigns) do
    ~H"""
      <div class="flex bg-base-200 pl-2 pr-7 py-3 items-center cursor-pointer" phx-click="toggle-section" phx-value-section_id={"pipeline-#{@pipeline.id}"}>

        <div class="flex flex-col">
          <div class=" flex flex-row items-center">
            <div class="flex flex-row w-8 h-8 rounded-full bg-white flex items-center justify-center">
              <.icon name="play-icon" class="w-5 h-5 text-blue-planning-300" />
            </div>
            <span class="text-blue-planning-300 text-xl font-bold ml-2">
              <%= @pipeline.name %>
              <span class="text-base-300 ml-2 rounded-md bg-white px-2 text-sm font-bold whitespace-nowrap"><%= Enum.count(@pipeline.emails) %> <%=ngettext("email", "emails", Enum.count(@pipeline.emails)) %></span>
            </span>
          </div>
          <p class="text:xs text-gray-400 lg:text-base ml-10">
            <%= @pipeline.description %>
          </p>
        </div>

        <div class="ml-auto">
          <%= if !Enum.member?(@collapsed_sections, "pipeline-#{@pipeline.id}") do %>
              <.icon name="down" class="w-5 h-5 stroke-2 text-blue-planning-300" />
            <% else %>
              <.icon name="up" class="w-5 h-5 stroke-2 text-blue-planning-300" />
            <% end %>
          </div>
      </div>


      <%= if Enum.member?(@collapsed_sections, "pipeline-#{@pipeline.id}") do %>
        <%= Enum.map(@pipeline.emails, fn email -> %>
          <div class="flex flex-col md:flex-row pl-2 pr-7 py-3 md:items-center justify-between">
            <div class="flex flex-row ml-2 mb-2">
              <div class="flex w-8 h-8 rounded-full items-center justify-center bg-base-200 mr-2">
                <.icon name="tick" class="w-5 h-5 text-blue-planning-300" />
              </div>
              <span class="text-blue-planning-300 text-sm font-bold ml-2">
                <%= if not is_nil(email.reminded_at) do %>
                  Completed <%= get_completed_date(email.reminded_at) %>
                <% end %>
                <p class="text-black text-xl">
                  <%= email.name %>
                </p>
                <div class="flex items-center bg-white">
                <.icon name="play-icon" class="w-4 h-4 text-blue-planning-300 mr-2" />
                  <p class="text-gray-400 text-sm"> <%= get_email_schedule_text(email.total_hours) %></p>
                </div>
              </span>
            </div>

            <div class="flex justify-end mr-2">
              <button class="flex flex-row items-center justify-center w-8 h-8 bg-base-200 mr-2 rounded-xl" phx-click="confirm-stop-email" phx-value-email_id={email.id}>
                <.icon name="stop" class="flex flex-col items-center justify-center w-5 h-5 text-red-sales-300"/>
              </button>
              <button disabled={!is_nil(email.reminded_at)} class="h-8 flex items-center px-2 py-1 btn-tertiary text-black font-bold  hover:border-blue-planning-300 mr-2 whitespace-nowrap" phx-click="send-email-now" phx-value-email_id={email.id} phx-value-pipeline_id={@pipeline.id}>
                Send now
              </button>
              <button class="h-8 flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75 whitespace-nowrap" phx-click="edit-email" phx-value-email_id={email.id} phx-value-pipeline_id={@pipeline.id}>
                <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-white" />
                Edit email
              </button>
            </div>
          </div>
        <% end) %>
    <% end %>
    """
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
    galleries = Galleries.get_galleries_by_job_id(job_id) |> Enum.map(& &1.id)

    IO.inspect(galleries, charlists: :as_lists)
    job = job_id |> Jobs.get_job_by_id()

    gallery_emails = EmailAutomation.get_emails_schedules_galleries(galleries)
    jobs_emails = EmailAutomation.get_emails_schedules_jobs(job_id)
    email_schedules = jobs_emails ++ gallery_emails

    socket
    |> assign(:type, job.type)
    |> assign(email_schedules: email_schedules)
  end

  defp get_email_schedule_text(0), do: "Send email immediately"

  defp get_email_schedule_text(hours) do
    %{calendar: calendar, count: count, sign: sign} = explode_hours(hours)
    sign = if sign == "+", do: "Later", else: "Earlier"
    calendar = calendar_text(calendar, count)
    "Send #{count} #{calendar} #{sign}"
  end

  defp calendar_text("Hour", count), do: ngettext("Hour", "Hours", count)
  defp calendar_text("Day", count), do: ngettext("Day", "Days", count)
  defp calendar_text("Month", count), do: ngettext("Month", "Months", count)
  defp calendar_text("Year", count), do: ngettext("Year", "Years", count)

  defp get_completed_date(date) do
    {:ok, converted_date} = NaiveDateTime.from_iso8601(date)
    converted_date |> Calendar.strftime("%m/%d/%Y")
  end

  defp valid_type?(%{assigns: %{selected_job_type: nil}}), do: false
  defp valid_type?(%{assigns: %{selected_job_type: _type}}), do: true
end
