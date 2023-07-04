defmodule PicselloWeb.Live.EmailAutomations.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  import Picsello.Onboardings, only: [save_intro_state: 3]
  import PicselloWeb.LiveHelpers

  import PicselloWeb.EmailAutomationLive.Shared,
    only: [get_pipline: 1, get_email_schedule_text: 1, explode_hours: 1, fetch_date_for_state: 2]

  import PicselloWeb.Gettext, only: [ngettext: 3]
  import Ecto.Query

  alias Picsello.{
    Galleries,
    Jobs,
    Orders,
    EmailAutomations,
    EmailAutomationSchedules,
    Repo
  }

  @impl true
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
        "intro-close-automations",
        _,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> assign(current_user: save_intro_state(current_user, "intro_automations", :dismissed))
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
  def handle_event(
        "send-email-now",
        %{"email_id" => id, "pipeline_id" => pipeline_id},
        %{assigns: %{job_id: job_id}} = socket
      ) do
    id = to_integer(id)
    pipeline_id = to_integer(pipeline_id)

    email =
      EmailAutomationSchedules.get_email_schedule_by_id(id)
      |> Repo.preload(email_automation_pipeline: [:email_automation_category])

    pipeline = get_pipline(pipeline_id)

    case email.gallery_id do
      nil ->
        job =
          Jobs.get_job_by_id(job_id)
          |> Repo.preload([:payment_schedules, :job_status, client: :organization])

        send_email(:job, pipeline.email_automation_category.type, email, job, pipeline.state)

      id ->
        gallery = Galleries.get_gallery!(id)

        send_email(
          :gallery,
          pipeline.email_automation_category.type,
          email,
          gallery,
          :hello
          # pipeline.state
        )
    end
    |> case do
      {:ok, _} -> socket |> put_flash(:success, "Email Sent Successfully")
      _ -> socket |> put_flash(:error, "Error in Sending Email")
    end
    |> assign_email_schedules()
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-email",
        %{"email_id" => id, "pipeline_id" => pipeline_id},
        %{assigns: %{current_user: current_user, type: type}} = socket
      ) do
    schedule_id = to_integer(id)
    pipeline_id = to_integer(pipeline_id)

    socket
    |> open_modal(PicselloWeb.EmailAutomationLive.EditEmailScheduleComponent, %{
      current_user: current_user,
      job_type: type,
      pipeline: get_pipline(pipeline_id),
      email: EmailAutomationSchedules.get_schedule_by_id(schedule_id)
    })
    |> noreply()
  end

  @impl true
  def handle_event("email-preview", %{"email_preview_id" => id}, socket) do
    _email_preview = EmailAutomationSchedules.get_schedule_by_id(id)
    socket |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "stop-email-schedule-" <> id}, socket) do
    id = String.to_integer(id)

    case EmailAutomationSchedules.update_email_schedule(id, %{is_stopped: true}) do
      {:ok, _} -> socket |> put_flash(:success, "Email Stopped Successfully")
      _ -> socket |> put_flash(:error, "Error in Updating Email")
    end
    |> close_modal()
    |> assign_email_schedules()
    |> noreply()
  end

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.EmailAutomationLive.Shared

  defp pipeline_section(assigns) do
    ~H"""
      <div class="md:my-5 md:mx-12 border border-base-200 rounded-lg">
        <% next_email = get_next_email_schdule_date(@category_type, @gallery_id, @job_id, @pipeline.id, @pipeline.state) %>
        <div class={classes("flex justify-between p-2", %{"opacity-60" => next_email.is_completed})}>
          <span class="pl-1 text-blue-planning-300 font-bold"> <%= next_email.text <> " " <> next_email.date %>
          </span>
        <%= if not is_nil(next_email.email_preview_id) do %>
          <span class="text-blue-planning-300 pr-4 underline" phx-click="email-preview" phx-value-email_preview_id={next_email.email_preview_id} >Preview</span>
        <% end %>
        </div>

        <div class={classes("flex bg-base-200 pl-2 pr-7 py-3 items-center cursor-pointer", %{"opacity-60" => next_email.is_completed})} phx-click="toggle-section" phx-value-section_id={"pipeline-#{@pipeline.id}"}>

          <div class="flex flex-col">
            <div class=" flex flex-row items-center">
              <div class="flex flex-row w-8 h-8 rounded-full bg-white flex items-center justify-center">
                <.icon name="play-icon" class="w-5 h-5 text-blue-planning-300" />
              </div>
              <span class="flex items-center text-blue-planning-300 text-xl font-bold ml-2">
                <%= @pipeline.name %>
                <span class="text-base-300 ml-2 rounded-md bg-white px-2 text-sm font-bold whitespace-nowrap"><%= Enum.count(@pipeline.emails) %> <%=ngettext("email", "emails", Enum.count(@pipeline.emails)) %></span>
              </span>
            </div>
            <p class="text:xs text-base-250 lg:text-base ml-10">
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
          <%= Enum.with_index(@pipeline.emails, fn email, index -> %>
              <% last_index = Enum.count(@pipeline.emails) - 1 %>
            <div class={classes("flex flex-col md:flex-row pl-2 pr-7 md:items-center justify-between", %{"opacity-60" => next_email.is_completed})}>
              <div class="flex flex-row ml-2 h-max">
                <div class={"h-auto pt-3 md:relative #{index != last_index && "md:before:absolute md:before:border md:before:h-full md:before:border-base-200 md:before:left-1/2 md:before:z-10 md:before:z-[-1]"}"}>
                  <div class="flex w-8 h-8 rounded-full items-center justify-center bg-base-200 z-40">
                  <%= if not is_nil(email.reminded_at) do %>
                    <.icon name="tick" class="w-5 h-5 text-blue-planning-300" />
                  <% else %>
                    <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
                  <% end %>
                  </div>
                </div>
                <span class="text-blue-planning-300 text-sm font-bold ml-4 py-3 ">
                  <%= if not is_nil(email.reminded_at) do %>
                    Completed <%= get_completed_date(email.reminded_at) %>
                  <% end %>
                  <p class="text-black text-xl">
                    <%= if email.private_name, do: email.private_name, else: email.name %>
                  </p>
                  <div class="flex items-center bg-white">
                  <.icon name="play-icon" class="w-4 h-4 text-blue-planning-300 mr-2" />
                    <p class="font-normal text-base-250 text-sm"> <%= get_email_schedule_text(email.total_hours) %></p>
                  </div>
                </span>
              </div>

              <div class="flex justify-end mr-2">
                <button disabled={!is_nil(email.reminded_at)} class={classes("flex flex-row items-center justify-center w-8 h-8 bg-base-200 mr-2 rounded-xl", %{"opacity-30 hover:cursor-not-allowed" => email.is_stopped || !is_nil(email.reminded_at)})} phx-click="confirm-stop-email" phx-value-email_id={email.id}>
                  <.icon name="stop" class="flex flex-col items-center justify-center w-5 h-5 text-red-sales-300"/>
                </button>
                <button disabled={!is_nil(email.reminded_at)} class={classes("h-8 flex items-center px-2 py-1 btn-tertiary text-black font-bold  hover:border-blue-planning-300 mr-2 whitespace-nowrap", %{"opacity-30 hover:cursor-not-allowed" => !is_nil(email.reminded_at)})} phx-click="send-email-now" phx-value-email_id={email.id} phx-value-pipeline_id={@pipeline.id}>
                  Send now
                </button>
                <button disabled={!is_nil(email.reminded_at)} class={classes("h-8 flex items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75 whitespace-nowrap", %{"opacity-30 hover:cursor-not-allowed" => !is_nil(email.reminded_at)})} phx-click="edit-email" phx-value-email_id={email.id} phx-value-pipeline_id={@pipeline.id}>
                  <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-white" />
                  Edit email
                </button>
              </div>
            </div>
          <% end) %>
      <% end %>
      </div>
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

    job = job_id |> Jobs.get_job_by_id()

    gallery_emails = EmailAutomationSchedules.get_emails_schedules_by_ids(galleries, :gallery)
    jobs_emails = EmailAutomationSchedules.get_emails_schedules_by_ids(job_id, :job)
    email_schedules = jobs_emails ++ gallery_emails

    socket
    |> assign(:type, job.type)
    |> assign(email_schedules: email_schedules)
  end

  defp get_next_email_schdule_date(category_type, gallery_id, job_id, pipeline_id, state) do
    email_schedule =
      EmailAutomations.query_get_email_schedule(category_type, gallery_id, job_id, pipeline_id)
      |> where([es], is_nil(es.reminded_at))
      |> order_by([es], asc: es.id)
      |> Repo.one()

    case email_schedule do
      nil ->
        last_completed_email =
          get_last_completed_email(category_type, gallery_id, job_id, pipeline_id)

        %{
          text: "Completed",
          date: last_completed_email.reminded_at |> Calendar.strftime("%m/%d/%Y"),
          email_preview_id: nil,
          is_completed: true
        }

      _ ->
        %{sign: sign} = explode_hours(email_schedule.total_hours)
        job = EmailAutomations.get_job(job_id)
        date = fetch_date_for_state(state, job)

        case date do
          nil ->
            %{text: "Transactional", date: "", email_preview_id: nil, is_completed: false}

          date ->
            %{
              text: "Next Email",
              date: next_schedule_format(date, sign, email_schedule.total_hours),
              email_preview_id: email_schedule.id,
              is_completed: false
            }
        end
    end
  end

  defp get_last_completed_email(category_type, gallery_id, job_id, pipeline_id) do
    EmailAutomations.query_get_email_schedule(category_type, gallery_id, job_id, pipeline_id)
    |> where([es], not is_nil(es.reminded_at))
    |> order_by([es], desc: es.id)
    |> Repo.one()
  end

  defp next_schedule_format(date, sign, hours) do
    if sign == "+" do
      DateTime.add(date, hours * 60 * 60)
    else
      DateTime.add(date, -1 * (hours * 60 * 60))
    end
    |> Calendar.strftime("%m/%d/%Y")
  end

  defp get_completed_date(date) do
    {:ok, converted_date} = NaiveDateTime.from_iso8601(date)
    converted_date |> Calendar.strftime("%m/%d/%Y")
  end

  defp send_email(:job, category_type, email, job, state) do
    EmailAutomations.send_now_email(
      category_type,
      email,
      job,
      state
    )
  end

  defp send_email(:gallery, _category_type, email, gallery, state)
       when state in [
              :gallery_send_link,
              :cart_abandoned,
              :gallery_expiration_soon,
              :gallery_password_changed
            ] do
    EmailAutomations.send_now_email(:gallery, email, gallery, state)
  end

  defp send_email(:gallery, _category_type, email, gallery, state) do
    result =
      gallery.id
      |> Orders.all()
      |> Enum.reduce({:ok, []}, fn order, {:ok, successful} ->
        case EmailAutomations.send_now_email(:order, email, order, state) do
          {:ok, _} -> {:ok, [order | successful]}
          {:error, error} -> {:error, error}
        end
      end)

    case result do
      {:ok, _} ->
        {:ok, "All emails sent successfully."}

      {:error, _} ->
        {:error, "One or more emails failed to send."}
    end
  end
end
