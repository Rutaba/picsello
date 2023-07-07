defmodule PicselloWeb.EmailAutomationLive.Shared do
  @moduledoc false
  use PicselloWeb, :live_component

  import PicselloWeb.LiveHelpers
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias Picsello.{Marketing, PaymentSchedules, EmailPresets.EmailPreset, EmailAutomations, Repo}
  alias Picsello.EmailAutomation.EmailSchedule

  @impl true
  def handle_info({:update_automation, %{message: message}}, socket) do
    socket
    |> assign_automation_pipelines()
    |> put_flash(:success, message)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:load_template_preview, component, body_html},
        %{assigns: %{current_user: current_user, modal_pid: modal_pid}} = socket
      ) do
    template_preview = Marketing.template_preview(current_user, body_html)

    send_update(
      modal_pid,
      component,
      id: component,
      template_preview: template_preview
    )

    socket
    |> noreply()
  end

  def make_email_presets_options(email_presets) do
    email_presets
    |> Enum.map(fn %{id: id, name: name} -> {name, id} end)
  end

  def email_preset_changeset(socket, email_preset, params \\ nil) do
    email_preset_changeset = build_email_changeset(email_preset, params)
    body_template = current(email_preset_changeset) |> Map.get(:body_template)

    if params do
      socket
    else
      socket
      |> push_event("quill:update", %{"html" => body_template})
    end
    |> assign(email_preset_changeset: email_preset_changeset)
  end

  def assign_automation_pipelines(
        %{assigns: %{current_user: current_user, selected_job_type: selected_job_type}} = socket
      ) do
    automation_pipelines =
      EmailAutomations.get_all_pipelines_emails(
        current_user.organization_id,
        selected_job_type.job_type
      )
      |> assign_category_pipeline_count()
      |> assign_pipeline_status()

    socket |> assign(:automation_pipelines, automation_pipelines)
  end

  def get_pipline(pipeline_id) do
    to_integer(pipeline_id)
    |> EmailAutomations.get_pipeline_by_id()
    |> Repo.preload([:email_automation_category, :email_automation_sub_category])
  end

  defp assign_category_pipeline_count(automation_pipelines) do
    automation_pipelines
    |> Enum.map(fn %{subcategories: subcategories} = category ->
      total_emails_count =
        subcategories
        |> Enum.reduce(0, fn subcategory, acc ->
          email_count =
            Enum.map(subcategory.pipelines, fn pipeline ->
              length(pipeline.emails)
            end)
            |> Enum.sum()

          email_count + acc
        end)

      Map.put(category, :total_emails_count, total_emails_count)
    end)
  end

  defp assign_pipeline_status(pipelines) do
    pipelines
    |> Enum.map(fn %{subcategories: subcategories} = category ->
      updated_sub_categories =
        Enum.map(subcategories, fn subcategory ->
          get_pipeline_status(subcategory)
        end)

      Map.put(category, :subcategories, updated_sub_categories)
    end)
  end

  defp get_pipeline_status(subcategory) do
    updated_pipelines =
      Enum.map(subcategory.pipelines, fn pipeline ->
        if Enum.any?(pipeline.emails, &(&1.status == :active)) do
          Map.put(pipeline, :status, "active")
        else
          Map.put(pipeline, :status, "disabled")
        end
      end)

    Map.put(subcategory, :pipelines, updated_pipelines)
  end

  def build_email_changeset(email_preset, params) do
    params =
      if params do
        params
      else
        email_preset
        |> Map.put(:template_id, email_preset.id)
        |> prepare_email_preset_params()
      end

    case email_preset do
      %EmailPreset{} ->
        EmailPreset.changeset(params)

      _ ->
        EmailSchedule.changeset(params)
    end
  end

  def prepare_email_preset_params(email_preset) do
    email_preset
    |> Map.from_struct()
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
  end

  def validate?(false, _), do: false

  def validate?(true, job_types) do
    Enum.any?(job_types, &Map.get(&1, :selected, false))
  end

  def get_email_schedule_text(0), do: "Send email immediately"

  def get_email_schedule_text(hours) do
    %{calendar: calendar, count: count, sign: sign} = explode_hours(hours)
    sign = if sign == "+", do: "Later", else: "Earlier"
    calendar = calendar_text(calendar, count)
    "Send #{count} #{calendar} #{sign}"
  end

  defp calendar_text("Hour", count), do: ngettext("Hour", "Hours", count)
  defp calendar_text("Day", count), do: ngettext("Day", "Days", count)
  defp calendar_text("Month", count), do: ngettext("Month", "Months", count)
  defp calendar_text("Year", count), do: ngettext("Year", "Years", count)

  def explode_hours(hours) do
    year = 365 * 24
    month = 30 * 24
    sign = if hours > 0, do: "+", else: "-"
    hours = make_positive_number(hours)

    cond do
      rem(hours, year) == 0 -> %{count: trunc(hours / year), calendar: "Year", sign: sign}
      rem(hours, month) == 0 -> %{count: trunc(hours / month), calendar: "Month", sign: sign}
      rem(hours, 24) == 0 -> %{count: trunc(hours / 24), calendar: "Day", sign: sign}
      true -> %{count: hours, calendar: "Hour", sign: sign}
    end
  end

  defp make_positive_number(no), do: if(no > 0, do: no, else: -1 * no)

  def fetch_date_for_state(_state, nil, nil, nil), do: nil

  def fetch_date_for_state(:gallery_send_link, nil, gallery, _order) do
    if not is_nil(gallery.gallery_send_at), do: gallery.gallery_send_at, else: nil
  end

  def fetch_date_for_state(:cart_abandoned, nil, gallery, _order) do
    card_abandoned? =
      Enum.any?(gallery.orders, fn order ->
        is_nil(order.placed_at) and is_nil(order.intent) and Enum.any?(order.digitals)
      end)

    if card_abandoned?, do: gallery.inserted_at, else: nil
  end

  def fetch_date_for_state(:gallery_expiration_soon, nil, gallery, _order) do
    next_date = Timex.shift(Timex.now(), days: 7)

    cond do
      not is_nil(gallery.expired_at) and Timex.after?(gallery.expired_at, next_date) ->
        gallery.expired_at

      true ->
        nil
    end
  end

  def fetch_date_for_state(:gallery_password_changed, nil, gallery, _order) do
    if not is_nil(gallery.password_regenerated_at), do: gallery.password_regenerated_at, else: nil
  end

  def fetch_date_for_state(:order_confirmation_physical, nil, _gallery, order) do
    if not is_nil(order.whcc_order), do: order.placed_at, else: nil
  end

  def fetch_date_for_state(:order_confirmation_digital, nil, _gallery, order) do
    if(Enum.any?(order.digital_line_items), do: order.placed_at, else: nil)
  end

  def fetch_date_for_state(:order_confirmation_digital_physical, nil, _gallery, order) do
    if(Enum.any?(order.digital_line_items) and not is_nil(order.whcc_order),
      do: order.placed_at,
      else: nil
    )
  end

  def fetch_date_for_state(:client_contact, job, _gallery, _order) do
    job |> Map.get(:inserted_at)
  end

  def fetch_date_for_state(state, job, _gallery, _order)
      when state in [:pays_retainer, :booking_proposal_sent] do
    job
    |> Map.get(:booking_proposals)
    |> Enum.sort_by(& &1.id)
    |> Enum.filter(fn proposal -> proposal.sent_to_client == true end)
    |> List.first()
    |> case do
      nil -> nil
      proposal -> proposal |> Map.get(:inserted_at)
    end
  end

  def fetch_date_for_state(:booking_event, job, _gallery, _order) do
    job
    |> Map.get(:booking_event)
    |> case do
      nil -> nil
      booking_event -> booking_event |> Map.get(:inserted_at)
    end
  end

  def fetch_date_for_state(:before_shoot, job, _gallery, _order) do
    today = NaiveDateTime.utc_now() |> Timex.end_of_day()

    job.shoots
    |> Enum.filter(fn item ->
      Timex.compare(today, item.starts_at, :days) <= 1
    end)
    |> (fn filtered_list ->
          if Enum.count(filtered_list) == 0,
            do: nil,
            else: List.first(filtered_list) |> Map.get(:starts_at)
        end).()
  end

  def fetch_date_for_state(:balance_due, job, _gallery, _order) do
    if PaymentSchedules.free?(job) do
      nil
    else
      job
      |> PaymentSchedules.next_due_payment()
      |> Map.get(:due_at)
    end
  end

  def fetch_date_for_state(:paid_full, job, _gallery, _order) do
    if PaymentSchedules.all_paid?(job) do
      job.payment_schedules
      |> PaymentSchedules.set_payment_schedules_order()
      |> List.first()
      |> Map.get(:paid_at)
    else
      nil
    end
  end

  def fetch_date_for_state(:offline_payment, job, _gallery, _order) do
    if PaymentSchedules.is_with_cash?(job) do
      PaymentSchedules.get_is_with_cash(job) |> List.first() |> Map.get(:inserted_at)
    else
      nil
    end
  end

  def fetch_date_for_state(:shoot_thanks, job, _gallery, _order) do
    today = NaiveDateTime.utc_now() |> Timex.end_of_day()

    job.shoots
    |> Enum.filter(fn item ->
      Timex.compare(today, item.starts_at, :minute) >= 0
    end)
    |> (fn filtered_list ->
          if Enum.count(filtered_list) == 0,
            do: nil,
            else: List.first(filtered_list) |> Map.get(:starts_at)
        end).()
  end

  def fetch_date_for_state(:post_shoot, job, _gallery, _order) do
    today = NaiveDateTime.utc_now() |> Timex.end_of_day()

    filter_shoots_count =
      job.shoots
      |> Enum.filter(fn item ->
        Timex.compare(today, item.starts_at, :minute) >= 0
      end)
      |> Enum.count()

    shoots_count = Enum.count(job.shoots)

    if shoots_count == filter_shoots_count and shoots_count >= 1 do
      job.shoots |> List.first() |> Map.get(:starts_at)
    else
      nil
    end
  end

  def fetch_date_for_state(_state, _job, _gallery, _order), do: nil
end
