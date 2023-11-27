defmodule PicselloWeb.Live.Admin.AutomationsSentTodayReport do
  @moduledoc "report for email automations sent today"
  use PicselloWeb, live_view: [layout: false]

  import Ecto.Query

  alias Picsello.{
    EmailAutomation.EmailScheduleHistory,
    Repo,
    Subscription,
    Accounts.User,
    Job,
    Client
  }

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:date_range, {start_time(), end_time()})
    |> assign_email_schedules_for_today()
    |> ok()
  end

  @impl true
  def handle_event("change-date", %{"date" => %{"automation_date" => automation_date}}, socket) do
    date_range = {start_time(automation_date), end_time(automation_date)}

    socket
    |> assign(:date_range, date_range)
    |> assign(:emails, get_scheduled_emails_for_today(date_range))
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100 flex items-center justify-between">
      <div>
        <h1 class="text-4xl font-bold">Automations Sent Today</h1>
        <%= live_redirect "Automations Report Index", to: Routes.admin_automations_report_index_path(@socket, :index), class: "link" %>
      </div>
      <.form :let={f} for={%{}} as={:date} phx-change="change-date">
        <div class="">
          <.date_picker_field class="" id="select_automation_date" form={f} field={:automation_date} input_placeholder="mm/dd/yyyy" input_label="Change Date" />
          <p class="opacity-50">(defaults to today—time range on selection is utc 00:00:00 to 23:59:59)</p>
        </div>
      </.form>
    </header>
    <div class="w-screen text-xs">
      <table class="border-2 w-full table-auto">
        <thead>
          <tr class="border-2 text-left">
            <th>Row # / Id</th>
            <th>Photog Sub Status</th>
            <th>Photog Email</th>
            <th>Photog Name</th>
            <th>Client Email</th>
            <th>Job Id</th>
            <th>Email Name</th>
            <th>ESH Inserted At—UTC</th>
            <th>Photog Timezone</th>
          </tr>
        </thead>
        <tbody>
          <%= for({%{email: email, user_name: user_name, job_id: job_id, name: name, subscription_status: subscription_status, inserted_at: inserted_at, id: id, user_time_zone: user_time_zone, client_email: client_email}, index} <- @emails |> Enum.with_index()) do %>
            <tr class="w-full ">
              <td class="py-1"><%= index %> - <%= id %></td>
              <td class="py-1"><%= subscription_status %></td>
              <td class="py-1"><%= email %></td>
              <td class="py-1"><%= user_name %></td>
              <td class="py-1"><%= client_email %></td>
              <td class="py-1"><%= job_id %></td>
              <td class="py-1"><%= name %></td>
              <td class="py-1"><%= inserted_at %></td>
              <td class="py-1"><%= user_time_zone %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  def assign_email_schedules_for_today(%{assigns: %{date_range: date_range}} = socket) do
    emails = get_scheduled_emails_for_today(date_range)
    socket |> assign(:emails, emails)
  end

  def get_scheduled_emails_for_today(date_range) do
    {start_date, end_date} = date_range

    from(u in User,
      join: s in Subscription,
      on: u.id == s.user_id,
      join: c in Client,
      on: u.organization_id == c.organization_id,
      join: j in Job,
      on: j.client_id == c.id and is_nil(j.completed_at),
      join: esh in EmailScheduleHistory,
      on:
        esh.job_id == j.id and esh.inserted_at >= ^start_date and esh.inserted_at <= ^end_date and
          is_nil(esh.stopped_at),
      select: %{
        user_id: u.id,
        user_time_zone: u.time_zone,
        email: u.email,
        user_name: u.name,
        subscription_status: s.status,
        job_id: esh.job_id,
        name: esh.name,
        inserted_at: esh.inserted_at,
        id: esh.id,
        client_email: c.email
      },
      order_by: [asc: u.email]
    )
    |> Repo.all()
  end

  defp end_time(date) do
    {:ok, new_date, _} = DateTime.from_iso8601("#{date} 23:59:59Z")

    new_date
  end

  defp end_time() do
    Date.utc_today()
    |> end_time()
  end

  defp start_time(date) do
    {:ok, new_date, _} = DateTime.from_iso8601("#{date} 00:00:00Z")

    new_date
  end

  defp start_time() do
    Date.utc_today()
    |> start_time()
  end
end
