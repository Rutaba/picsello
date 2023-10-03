defmodule PicselloWeb.EmailAutomationLive.Shared do
  @moduledoc false
  use Phoenix.Component
  import Phoenix.LiveView
  import PicselloWeb.Gettext, only: [ngettext: 3]

  import PicselloWeb.LiveHelpers
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias PicselloWeb.Shared.ShortCodeComponent

  alias Picsello.{
    Marketing,
    PaymentSchedules,
    EmailPresets.EmailPreset,
    EmailAutomations,
    EmailAutomationSchedules,
    EmailAutomation.EmailSchedule,
    EmailAutomation.EmailScheduleHistory,
    Repo,
    Utils,
    UserCurrencies
  }

  # @impl true
  def handle_info({:update_automation, %{message: message}}, socket) do
    socket
    |> assign_automation_pipelines()
    |> put_flash(:success, message)
    |> noreply()
  end

  # @impl true
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

  @doc """
  Compiles the section values and renders the body_html, and assigns the following to socket:

    - template_preview
    - email_preset_changeset
    - step

  Returns `{:noreply, socket}`
  """
  def preview_template(
        %{
          assigns:
            %{
              job: job,
              current_user: current_user,
              email_preset_changeset: changeset,
              module_name: module_name
            } = assigns
        } = socket
      ) do
    user_currency = UserCurrencies.get_user_currency(current_user.organization_id).currency

    body_html =
      Ecto.Changeset.get_field(changeset, :body_template)
      |> :bbmustache.render(get_sample_values(current_user, job, user_currency), key_type: :atom)
      |> Utils.normalize_body_template()

    Process.send_after(self(), {:load_template_preview, module_name, body_html}, 50)

    socket
    |> assign(:template_preview, :loading)
    |> assign(step: next_step(assigns))
    |> noreply()
  end

  def make_email_presets_options(email_presets) do
    email_presets
    |> Enum.map(fn %{id: id, name: name} -> {name, id} end)
  end

  def make_sign_options(state) do
    state = if is_atom(state), do: Atom.to_string(state), else: state

    cond do
      state in ["before_shoot", "gallery_expiration_soon"] ->
        [[key: "Before", value: "-"], [key: "After", value: "+", disabled: true]]

      state in ["balance_due", "offline_payment"] ->
        [[key: "Before", value: "-"], [key: "After", value: "+"]]

      true ->
        [[key: "Before", value: "-", disabled: true], [key: "After", value: "+"]]
    end
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

  def get_selected_job_types(job_types, job_type) do
    job_types
    |> Enum.map(&%{id: &1.job_type, label: &1.job_type, selected: &1.job_type == job_type.name})
  end

  def get_sample_values(user, job, user_currency) do
    ShortCodeComponent.variables_codes(:gallery, user, job, user_currency)
    |> Enum.map(&Enum.map(&1.variables, fn variable -> {variable.name, variable.sample} end))
    |> List.flatten()
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  def sort_emails(emails, state) do
    emails = Enum.sort_by(emails, &{:asc, Map.fetch(&1, :inserted_at)})

    email_with_immediate_status = Enum.filter(emails, &(&1.total_hours == 0))

    if state?(state) && Enum.any?(email_with_immediate_status) do
      {first_email, unsorted_emails} = email_with_immediate_status |> List.pop_at(0)
      pending_emails = unsorted_emails ++ Enum.filter(emails, &(&1.total_hours != 0))
      [first_email | Enum.sort_by(pending_emails, &Map.fetch(&1, :total_hours))]
    else
      Enum.sort_by(emails, &Map.fetch(&1, :total_hours))
    end
  end

  defp state?(state) do
    if(is_atom(state), do: Atom.to_string(state), else: state)
    |> String.contains?("manual_")
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

  def get_email_schedule_text(0, state, _, index, _job_type, _organization_id) do
    if state?(state) && index == 0 do
      "Photographer Sends"
    else
      "Send email immediately"
    end
  end

  def get_email_schedule_text(hours, state, emails, index, job_type, _organization_id) do
    %{calendar: calendar, count: count, sign: sign} = get_email_meta(hours)
    email = get_preceding_email(emails, index)

    sub_text =
      cond do
        # state in ["client_contact", "maual_booking_proposal_sent"] ->
        #   "the prior email \"#{get_email_name(email, job_type)}\" has been sent if no response from the client"
        state in ["before_shoot", "shoot_thanks", "post_shoot"] ->
          "the shoot date"

        state == "after_gallery_send_feedback" ->
          "the gallery send"

        state == "cart_abandoned" and index == 0 ->
          "client abandons cart"

        state == "cart_abandoned" ->
          "sending \"#{get_email_name(email, job_type)}\""

        state == "gallery_expiration_soon" ->
          "gallery expiration date"

        state in ["client_contact", "manual_thank_you_lead", "manual_booking_proposal_sent"] ->
          "sending \"#{get_email_name(email, job_type)}\" and if no response from the client"

        true ->
          "the prior email \"#{get_email_name(email, job_type)}\" has been sent if no response from the client"
      end

    "Send #{count} #{calendar} #{sign} #{sub_text}"
  end

  def get_email_name(email, job_type) do
    type = if job_type, do: job_type, else: String.capitalize(email.job_type)
    if email.private_name, do: email.private_name, else: "#{type} - " <> email.name
  end

  def email_header(assigns) do
    assigns = assigns |> Enum.into(%{index: -1})

    ~H"""
      <div class="flex flex-row mt-2 mb-4 items-center">
        <div class="flex mr-2">
          <div class="flex items-center justify-center w-8 h-8 rounded-full bg-blue-planning-300">
            <.icon name="envelope" class="w-4 h-4 text-white fill-current"/>
          </div>
        </div>
        <div class="flex flex-col ml-2">
          <p><b> <%= @email.type |> Atom.to_string() |> String.capitalize()%>:</b> <%= get_email_name(@email, nil) %></p>
          <p class="text-sm text-base-250">
            <%= if @email.total_hours == 0 do %>
              <%= get_email_schedule_text(0, @pipeline.state, nil, @index, nil, nil) %>
            <% else %>
              <% %{calendar: calendar, count: count, sign: sign} = get_email_meta(@email.total_hours) %>
              <%= "Send email #{count} #{calendar} #{sign} #{String.downcase(@pipeline.name)}" %>
            <% end %>
          </p>
        </div>
      </div>
    """
  end

  def get_preceding_email(emails, index) do
    {email, _} = List.pop_at(emails, index - 1)
    if email, do: email, else: List.last(emails)
  end

  defp get_email_meta(hours) do
    %{calendar: calendar, count: count, sign: sign} = explode_hours(hours)
    sign = if sign == "+", do: "after", else: "before"
    calendar = calendar_text(calendar, count)

    %{calendar: calendar, count: count, sign: sign}
  end

  defp calendar_text("Hour", count), do: ngettext("hour", "hours", count)
  defp calendar_text("Day", count), do: ngettext("day", "days", count)
  defp calendar_text("Month", count), do: ngettext("month", "months", count)
  defp calendar_text("Year", count), do: ngettext("year", "years", count)

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

  def is_state_manually_trigger(state) do
    String.starts_with?(to_string(state), "manual")
  end

  @doc """
    if state is manual then fetch reminded_at of last email which is sent
    else fetch_date_for_state to handle all other states
  """
  def fetch_date_for_state_maybe_manual(state, email, pipeline_id, job, gallery, order) do
    job = Repo.preload(job, [:booking_event])
    job_id = get_job_id(job)
    gallery_id = get_gallery_id(gallery, order)
    type = if job_id, do: :job, else: :gallery

    last_completed_email =
      EmailAutomationSchedules.get_last_completed_email(
        type,
        gallery_id,
        job_id,
        pipeline_id,
        state
      )

    if is_state_manually_trigger(state) do
      case last_completed_email do
        nil -> nil
        schedule -> schedule.reminded_at
      end
    else
      fetch_date_for_state(state, email, last_completed_email, job, gallery, order)
    end
  end

  def fetch_date_for_state(_state, _email, _last_completed_email, nil, nil, nil), do: nil

  def fetch_date_for_state(
        :gallery_send_link,
        _email,
        last_completed_email,
        _job,
        gallery,
        _order
      ) do
    if is_nil(gallery.gallery_send_at),
      do: nil,
      else: get_date_for_schedule(last_completed_email, gallery.gallery_send_at)
  end

  def fetch_date_for_state(:cart_abandoned, _email, last_completed_email, _job, gallery, _order) do
    card_abandoned? =
      Enum.any?(gallery.orders, fn order ->
        is_nil(order.placed_at) and is_nil(order.intent) and Enum.any?(order.digitals)
      end)

    if card_abandoned?,
      do: get_date_for_schedule(last_completed_email, gallery.inserted_at),
      else: nil
  end

  def fetch_date_for_state(
        :gallery_expiration_soon,
        email,
        _last_completed_email,
        _job,
        gallery,
        _order
      ) do
    %{calendar: calendar, count: count} = explode_hours(email.total_hours)
    time_calendar = get_timex_calendar(calendar)
    today = NaiveDateTime.utc_now() |> Timex.end_of_day()

    cond do
      is_nil(gallery.expired_at) ->
        nil

      not is_nil(gallery.expired_at) and
          Timex.compare(gallery.expired_at, today, time_calendar) >= count ->
        gallery.expired_at

      true ->
        nil
    end
  end

  def fetch_date_for_state(
        :gallery_password_changed,
        _email,
        last_completed_email,
        _job,
        gallery,
        _order
      ) do
    if is_nil(gallery.password_regenerated_at),
      do: nil,
      else: get_date_for_schedule(last_completed_email, gallery.password_regenerated_at)
  end

  def fetch_date_for_state(
        :after_gallery_send_feedback,
        email,
        _last_completed_email,
        _job,
        gallery,
        _order
      ) do
    today = NaiveDateTime.utc_now() |> Timex.end_of_day()
    %{calendar: calendar, count: count} = explode_hours(email.total_hours)
    time_calendar = get_timex_calendar(calendar)

    cond do
      is_nil(gallery.gallery_send_at) ->
        nil

      Timex.compare(today, gallery.gallery_send_at, time_calendar) >= count ->
        gallery.gallery_send_at

      true ->
        nil
    end
  end

  def fetch_date_for_state(
        :order_confirmation_physical,
        _email,
        last_completed_email,
        _job,
        _gallery,
        order
      ) do
    if is_nil(order.whcc_order),
      do: nil,
      else: get_date_for_schedule(last_completed_email, order.placed_at)
  end

  def fetch_date_for_state(
        :order_confirmation_digital,
        _email,
        last_completed_email,
        _job,
        _gallery,
        order
      ) do
    if(Enum.any?(order.digital_line_items),
      do: get_date_for_schedule(last_completed_email, order.placed_at),
      else: nil
    )
  end

  def fetch_date_for_state(
        :order_confirmation_digital_physical,
        _email,
        last_completed_email,
        _job,
        _gallery,
        order
      ) do
    if(Enum.any?(order.digital_line_items) or not is_nil(order.whcc_order),
      do: get_date_for_schedule(last_completed_email, order.placed_at),
      else: nil
    )
  end

  def fetch_date_for_state(:client_contact, _email, last_completed_email, job, _gallery, _order) do
    lead_date = job |> Map.get(:inserted_at)
    get_date_for_schedule(last_completed_email, lead_date)
  end

  def fetch_date_for_state(state, _email, last_completed_email, job, _gallery, _order)
      when state in [:pays_retainer, :thanks_booking] do
    payment_schedules = PaymentSchedules.payment_schedules(job)

    if !PaymentSchedules.is_with_cash?(job) and Enum.count(payment_schedules) > 0 do
      payment_date = payment_schedules |> List.first() |> Map.get(:paid_at)
      get_date_for_schedule(last_completed_email, payment_date)
    else
      nil
    end
  end

  def fetch_date_for_state(:abandoned_emails, _email, last_completed_email, job, _gallery, _order) do
    if is_nil(job.archived_at),
      do: nil,
      else: get_date_for_schedule(last_completed_email, job.archived_at)
  end

  def fetch_date_for_state(
        state,
        _email,
        last_completed_email,
        job,
        _gallery,
        _order
      )
      when state in [:pays_retainer_offline, :thanks_booking] do
    if PaymentSchedules.is_with_cash?(job) do
      payment_offline =
        PaymentSchedules.get_is_with_cash(job) |> List.first() |> Map.get(:inserted_at)

      get_date_for_schedule(last_completed_email, payment_offline)
    else
      nil
    end
  end

  def fetch_date_for_state(:before_shoot, email, _last_completed_email, job, _gallery, _order) do
    today = NaiveDateTime.utc_now() |> Timex.end_of_day()
    %{calendar: calendar, count: count} = explode_hours(email.total_hours)
    time_calendar = get_timex_calendar(calendar)

    job.shoots
    |> Enum.filter(fn item ->
      Timex.compare(item.starts_at, today, time_calendar) == count
    end)
    |> (fn filtered_list ->
          if Enum.empty?(filtered_list),
            do: nil,
            else: List.first(filtered_list) |> Map.get(:starts_at)
        end).()
  end

  def fetch_date_for_state(:balance_due, _email, last_completed_email, job, _gallery, _order) do
    payment_schedules = PaymentSchedules.payment_schedules(job)
    invoiced_due_date = PaymentSchedules.remainder_due_on(job)

    if is_nil(invoiced_due_date) or
         (PaymentSchedules.free?(job) and Enum.empty?(payment_schedules)) do
      nil
    else
      due_at =
        job
        |> PaymentSchedules.next_due_payment()
        |> Map.get(:due_at)

      get_date_for_schedule(last_completed_email, due_at)
    end
  end

  def fetch_date_for_state(:offline_payment, _email, last_completed_email, job, _gallery, _order) do
    invoiced_due_date = PaymentSchedules.remainder_due_on(job)

    offline_dues =
      PaymentSchedules.payment_schedules(job)
      |> Enum.filter(&(is_nil(&1.paid_at) and &1.type in ["cash", "check"]))
      |> Enum.sort_by(& &1.due_at, :asc)

    if !is_nil(invoiced_due_date) and !Enum.empty?(offline_dues) do
      due_at = List.first(offline_dues) |> Map.get(:due_at)

      get_date_for_schedule(last_completed_email, due_at)
    else
      nil
    end
  end

  def fetch_date_for_state(:paid_full, _email, last_completed_email, job, _gallery, _order) do
    payment_schedules = PaymentSchedules.payment_schedules(job)

    all_paid_online =
      payment_schedules
      |> Enum.all?(fn p -> not is_nil(p.paid_at) and p.type not in ["check", "cash"] end)

    if all_paid_online and Enum.count(payment_schedules) > 0 do
      paid_at =
        payment_schedules
        |> List.last()
        |> Map.get(:paid_at)

      get_date_for_schedule(last_completed_email, paid_at)
    else
      nil
    end
  end

  def fetch_date_for_state(
        :paid_offline_full,
        _email,
        last_completed_email,
        job,
        _gallery,
        _order
      ) do
    payment_schedules = PaymentSchedules.payment_schedules(job)

    all_paid_offline =
      payment_schedules
      |> Enum.all?(fn p -> not is_nil(p.paid_at) and p.type in ["check", "cash"] end)

    if all_paid_offline and Enum.count(payment_schedules) > 0 do
      paid_at =
        payment_schedules
        |> List.last()
        |> Map.get(:paid_at)

      get_date_for_schedule(last_completed_email, paid_at)
    else
      nil
    end
  end

  def fetch_date_for_state(:shoot_thanks, email, _last_completed_email, job, _gallery, _order) do
    today = NaiveDateTime.utc_now() |> Timex.end_of_day()
    %{calendar: calendar, count: count} = explode_hours(email.total_hours)
    time_calendar = get_timex_calendar(calendar)

    job.shoots
    |> Enum.filter(fn item ->
      Timex.compare(today, item.starts_at, time_calendar) >= count
    end)
    |> (fn filtered_list ->
          if Enum.empty?(filtered_list),
            do: nil,
            else: List.first(filtered_list) |> Map.get(:starts_at)
        end).()
  end

  def fetch_date_for_state(:post_shoot, email, _last_completed_email, job, _gallery, _order) do
    today = NaiveDateTime.utc_now() |> Timex.end_of_day()
    %{calendar: calendar, count: count} = explode_hours(email.total_hours)
    time_calendar = get_timex_calendar(calendar)

    filter_shoots_count =
      Enum.count(job.shoots, fn item ->
        Timex.compare(today, item.starts_at, time_calendar) >= count
      end)

    shoots_count = Enum.count(job.shoots)

    if shoots_count == filter_shoots_count and shoots_count >= 1 do
      job.shoots |> List.first() |> Map.get(:starts_at)
    else
      nil
    end
  end

  def fetch_date_for_state(_state, _email, _last_completed_email, _job, _gallery, _order), do: nil

  defp get_date_for_schedule(nil, date), do: date
  defp get_date_for_schedule(email, _date), do: email.reminded_at

  defp get_timex_calendar("Year"), do: :years
  defp get_timex_calendar("Month"), do: :months
  defp get_timex_calendar("Day"), do: :days
  defp get_timex_calendar("Hour"), do: :hours

  @doc """
    Insert all emails templates for jobs & leads in email schedules
  """
  def job_emails(type, organization_id, job_id, types, skip_states \\ [""]) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    emails =
      EmailAutomations.get_emails_for_schedule(organization_id, type, types)
      |> Enum.map(fn email_data ->
        state = Map.get(email_data, :email_automation_pipeline) |> Map.get(:state)

        if state not in skip_states do
          [
            job_id: job_id,
            total_hours: email_data.total_hours,
            condition: email_data.condition,
            body_template: email_data.body_template,
            name: email_data.name,
            subject_template: email_data.subject_template,
            private_name: email_data.private_name,
            email_automation_pipeline_id: email_data.email_automation_pipeline_id,
            organization_id: organization_id,
            inserted_at: now,
            updated_at: now
          ]
        end
      end)
      |> Enum.filter(&(&1 != nil))

    previous_emails_schedules = EmailAutomationSchedules.get_emails_by_job(EmailSchedule, job_id)

    previous_emails_history =
      EmailAutomationSchedules.get_emails_by_job(EmailScheduleHistory, job_id)

    if Enum.empty?(previous_emails_schedules) and Enum.empty?(previous_emails_history) do
      emails
    else
      []
    end
  end

  def insert_job_emails_from_gallery(gallery, types) do
    gallery =
      gallery
      |> Repo.preload([:job, organization: [organization_job_types: :jobtype]], force: true)

    job_type = gallery.job.type
    organization_id = gallery.organization.id
    job_emails(job_type, organization_id, gallery.job.id, types)
  end

  @doc """
    Insert all emails templates for galleries, When gallery created it fetch
    all email templates for gallery category and insert in email schedules
  """
  def gallery_order_emails(gallery, order \\ nil) do
    gallery =
      if order, do: order |> Repo.preload(gallery: :job) |> Map.get(:gallery), else: gallery

    gallery =
      gallery
      |> Repo.preload([:job, organization: [organization_job_types: :jobtype]], force: true)

    type = gallery.job.type

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    skip_sub_categories =
      if order,
        do: ["gallery_notification_emails", "order_status_emails"],
        else: ["order_confirmation_emails", "order_status_emails"]

    order_id = if order, do: order.id, else: nil

    emails =
      EmailAutomations.get_emails_for_schedule(
        gallery.organization.id,
        type,
        [:gallery],
        skip_sub_categories
      )
      |> Enum.map(fn email_data ->
        state = Map.get(email_data, :email_automation_pipeline) |> Map.get(:state)

        if state not in [
             :gallery_password_changed,
             :order_confirmation_physical,
             :order_confirmation_digital
           ] do
          [
            gallery_id: gallery.id,
            order_id: order_id,
            total_hours: email_data.total_hours,
            condition: email_data.condition,
            body_template: email_data.body_template,
            name: email_data.name,
            subject_template: email_data.subject_template,
            private_name: email_data.private_name,
            email_automation_pipeline_id: email_data.email_automation_pipeline_id,
            organization_id: gallery.organization.id,
            inserted_at: now,
            updated_at: now
          ]
        end
      end)
      |> Enum.filter(&(&1 != nil))

    previous_emails =
      if order,
        do: EmailAutomationSchedules.get_emails_by_order(EmailSchedule, order.id),
        else: EmailAutomationSchedules.get_emails_by_gallery(EmailSchedule, gallery.id)

    previous_emails_history =
      if order,
        do: EmailAutomationSchedules.get_emails_by_order(EmailScheduleHistory, order.id),
        else: EmailAutomationSchedules.get_emails_by_gallery(EmailScheduleHistory, gallery.id)

    if Enum.empty?(previous_emails) and Enum.empty?(previous_emails_history) do
      emails
    else
      []
    end
  end

  def insert_order_emails(gallery, order) do
    emails = gallery_order_emails(gallery, order)

    case Repo.insert_all(EmailSchedule, emails) do
      {count, nil} -> {:ok, count}
      _ -> {:error, "error insertion"}
    end
  end

  def insert_job_emails(type, organization_id, job_id, types, skip_states \\ [""]) do
    emails = job_emails(type, organization_id, job_id, types, skip_states)

    case Repo.insert_all(EmailSchedule, emails) do
      {count, nil} -> {:ok, count}
      _ -> {:error, "error insertion"}
    end
  end

  def assign_collapsed_sections(socket) do
    sub_categories = EmailAutomations.get_sub_categories() |> Enum.map(fn x -> x.name end)

    socket
    |> assign(:collapsed_sections, sub_categories)
  end

  @doc """
  Normalizes the "status" parameter in a map of parameters.

  This function accepts a map of parameters (`params`) and normalizes the "status" parameter. It checks if "status" is
  equal to "true" or "active" and replaces it with `:active`, or if it's anything else, it replaces it with `:disabled`.
  The normalized parameters are then returned.

  ## Parameters

      - `params` (map()): A map of parameters.

  ## Returns

      map(): A map of parameters with the "status" parameter normalized.

  ## Example

      ```elixir
      # Normalize the "status" parameter in a map of parameters
      iex> params = %{"status" => "true", "name" => "John"}
      iex> maybe_normalize_params(params)
      %{"status" => :active, "name" => "John"}
      iex> maybe_normalize_params(nil)
      nil

  ## Notes

      This function is useful for normalizing specific parameters within a map.
  """
  @spec maybe_normalize_params(nil) :: nil
  def maybe_normalize_params(nil), do: nil

  @spec maybe_normalize_params(map()) :: map()
  def maybe_normalize_params(params) do
    {_, params} =
      get_and_update_in(
        params,
        ["status"],
        &{&1, if(&1 in ["true", "active"], do: :active, else: :disabled)}
      )

    params
  end

  @doc """
  Takes the html body and split it on the basis of search_param
  and flattens the html body to plain-text.

  Returns a string
  """
  def get_plain_text(html_text, to_search) do
    if html_text |> String.contains?(to_search) do
      html_text
      |> String.split("{{##{to_search}}}")
      |> Enum.at(1)
      |> String.split("{{/#{to_search}}}")
      |> Enum.at(0)
      |> HtmlSanitizeEx.strip_tags()
    end
  end

  @doc """
  Takes the step and steps assigns and return what would be the next step

  Returns an atom, i.e. :edit_email or :preview_email
  """
  def next_step(%{step: step, steps: steps}) do
    Enum.at(steps, Enum.find_index(steps, &(&1 == step)) + 1)
  end

  defp get_job_id(job) when is_map(job), do: job.id
  defp get_job_id(_), do: nil
  defp get_gallery_id(gallery, _order) when is_map(gallery), do: gallery.id
  defp get_gallery_id(_gallery, order) when is_map(order), do: order.gallery.id
  defp get_gallery_id(_gallery, _order), do: nil
end
