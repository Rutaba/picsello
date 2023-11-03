defmodule PicselloWeb.EmailAutomationLive.Shared do
  @moduledoc false
  require Logger

  use Phoenix.Component
  import Phoenix.LiveView

  import PicselloWeb.LiveHelpers
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias PicselloWeb.Shared.ShortCodeComponent

  alias Picsello.{
    Marketing,
    Shoots,
    PaymentSchedules,
    PaymentSchedule,
    EmailPresets.EmailPreset,
    EmailAutomations,
    EmailAutomationSchedules,
    EmailAutomation.EmailSchedule,
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
    total_hours = assigns.email.total_hours

    body_html =
      Ecto.Changeset.get_field(changeset, :body_template)
      |> :bbmustache.render(get_sample_values(current_user, job, user_currency, total_hours),
        key_type: :atom
      )
      |> Utils.normalize_body_template()

    Process.send_after(self(), {:load_template_preview, module_name, body_html}, 50)

    socket
    |> assign(:template_preview, :loading)
    |> assign(step: next_step(assigns))
    |> noreply()
  end

  def make_email_presets_options(email_presets, state) do
    email_presets
    |> sort_emails(state)
    |> Enum.with_index(fn email, index ->
      name = get_email_name(email, nil, index, Atom.to_string(state))
      {name, email.id}
    end)
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

  def get_sample_values(user, job, user_currency, total_hours) do
    ShortCodeComponent.variables_codes(:gallery, user, job, user_currency, total_hours)
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

  defp get_email_schedule_name(0, _index, _state, name), do: name

  defp get_email_schedule_name(hours, 0, "before_shoot", name),
    do: get_email_schedule_name(hours, 1, "before_shoot", name)

  defp get_email_schedule_name(_hours, 0, _state, name), do: name

  defp get_email_schedule_name(hours, _index, state, name) when state not in ["post_shoot"] do
    %{calendar: calendar, count: count, sign: sign} =
      EmailAutomations.get_email_meta(hours, PicselloWeb.Helpers)

    "#{name} - #{count} #{calendar} #{sign}"
  end

  defp get_email_schedule_name(_hours, _index, _state, name), do: name

  def get_email_schedule_text(0, state, _, index, _job_type, _organization_id) do
    if state?(state) && index == 0 do
      "Photographer Sends"
    else
      "Send email immediately"
    end
  end

  def get_email_schedule_text(hours, state, emails, index, job_type, _organization_id) do
    %{calendar: calendar, count: count, sign: sign} =
      EmailAutomations.get_email_meta(hours, PicselloWeb.Helpers)

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
          "sending \"#{get_email_name(email, job_type, 0, nil)}\""

        state == "gallery_expiration_soon" ->
          "gallery expiration date"

        state in ["client_contact", "manual_thank_you_lead", "manual_booking_proposal_sent"] ->
          "sending \"#{get_email_name(email, job_type, 0, nil)}\" and if no response from the client"

        true ->
          "the prior email \"#{get_email_name(email, job_type, 0, nil)}\" has been sent if no response from the client"
      end

    "Send #{count} #{calendar} #{sign} #{sub_text}"
  end

  def get_email_name(email, job_type, index, state) do
    type = if job_type, do: job_type, else: String.capitalize(email.job_type)

    if email.private_name do
      email.private_name
    else
      name = "#{type} - " <> email.name
      get_email_schedule_name(email.total_hours, index, state, name)
    end
    |> Utils.capitalize_all_words()
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
          <p><b> <%= @email.type |> Atom.to_string() |> String.capitalize()%>:</b> <%= get_email_name(@email, nil, 0, nil) %></p>
          <p class="text-sm text-base-250">
            <%= if @email.total_hours == 0 do %>
              <%= get_email_schedule_text(0, @pipeline.state, nil, @index, nil, nil) %>
            <% else %>
              <% %{calendar: calendar, count: count, sign: sign} = EmailAutomations.get_email_meta(@email.total_hours, PicselloWeb.Helpers) %>
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

  defp hours_to_days(hours), do: hours / 24

  def is_state_manually_trigger(state) do
    String.starts_with?(to_string(state), "manual")
  end

  @doc """
    if state is manual then fetch reminded_at of last email which is sent
    else fetch_date_for_state to handle all other states
  """
  def fetch_date_for_state_maybe_manual(state, email, pipeline_id, job, gallery, order) do
    job = Repo.preload(job, [:booking_event, client: [organization: :user]])
    job_id = get_job_id(job)
    gallery_id = get_gallery_id(gallery, order)
    order = if order, do: Repo.preload(order, [:digitals]), else: nil
    type = if job_id, do: :job, else: :gallery

    last_completed_email =
      EmailAutomationSchedules.get_last_completed_email(
        type,
        gallery_id,
        nil,
        job_id,
        pipeline_id,
        state,
        __MODULE__
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
    if is_nil(gallery) || is_nil(gallery.gallery_send_at),
      do: nil,
      else: get_date_for_schedule(last_completed_email, gallery.gallery_send_at)
  end

  def fetch_date_for_state(:cart_abandoned, _email, last_completed_email, _job, gallery, _order) do
    card_abandoned? =
      Enum.any?(gallery.orders, fn order ->
        order = Repo.preload(order, [:digitals])
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
    # Examples
    # gallery.expired_at is ~D[2023-10-20]
    # today is ~D[2023-10-09]
    # diffrence days is 12 days
    # send 7 days before expiration 12 <= 7

    # gallery.expired_at is ~D[2023-10-20]
    # today is ~D[2023-10-13]
    # diffrence days is 7 days
    # send 7 days before expiration 7 <= 7

    days_to_compare = hours_to_days(email.total_hours)
    %{sign: sign} = EmailAutomations.explode_hours(email.total_hours)
    today = DateTime.utc_now()

    cond do
      is_nil(gallery.expired_at) ->
        nil

      is_send_time?(Date.diff(gallery.expired_at, today), abs(days_to_compare), sign) ->
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
    # Examples
    # gallery.gallery_send_at is ~D[2023-10-20]
    # today is ~D[2023-10-09]
    # difference is -12 days
    # send 7 days after gallery send -12 >= 7

    # gallery.gallery_send_at is ~D[2023-10-20]
    # today is ~D[2023-10-23]
    # difference is 3 days
    # send 7 days after gallery send 3 >= 7

    # gallery.gallery_send_at is ~D[2023-10-20]
    # today is ~D[2023-10-27]
    # difference is 7 days
    # send 7 days after gallery send 7 >= 7

    days_to_compare = hours_to_days(email.total_hours)
    today = DateTime.utc_now()

    %{sign: sign} = EmailAutomations.explode_hours(email.total_hours)

    cond do
      is_nil(gallery.gallery_send_at) ->
        nil

      is_send_time?(Date.diff(today, gallery.gallery_send_at), abs(days_to_compare), sign) ->
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
    if(Enum.any?(order.digitals),
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
    if is_nil(order.placed_at),
      do: nil,
      else: get_date_for_schedule(last_completed_email, order.placed_at)
  end

  def fetch_date_for_state(:client_contact, _email, last_completed_email, job, _gallery, _order) do
    lead_date = job |> Map.get(:inserted_at)
    get_date_for_schedule(last_completed_email, lead_date)
  end

  def fetch_date_for_state(:thanks_booking, _email, last_completed_email, job, _gallery, _order) do
    payment_schedules = PaymentSchedules.payment_schedules(job)
    any_with_cash? = PaymentSchedules.is_with_cash?(job)

    paid_at =
      payment_schedules
      |> Enum.filter(&(!is_nil(&1.paid_at)))

    cond do
      Enum.any?(paid_at) ->
        payment_date = paid_at |> List.first() |> Map.get(:paid_at)
        get_date_for_schedule(last_completed_email, payment_date)

      any_with_cash? ->
        payment_date = payment_schedules |> List.first() |> Map.get(:inserted_at)
        get_date_for_schedule(last_completed_email, payment_date)

      true ->
        nil
    end
  end

  def fetch_date_for_state(:pays_retainer, _email, last_completed_email, job, _gallery, _order) do
    payment_schedules = PaymentSchedules.payment_schedules(job)

    online_pays =
      payment_schedules
      |> Enum.filter(&(!is_nil(&1.paid_at) and &1.type == "stripe"))
      |> Enum.sort_by(& &1.paid_at, :asc)

    if Enum.any?(online_pays) and !PaymentSchedules.all_paid?(job) do
      payment_date = online_pays |> List.first() |> Map.get(:paid_at)
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
        :pays_retainer_offline,
        _email,
        last_completed_email,
        job,
        _gallery,
        _order
      ) do
    payment_schedules = PaymentSchedules.payment_schedules(job)

    offline_pays =
      payment_schedules
      |> Enum.filter(&(!is_nil(&1.paid_at) and &1.type != "stripe"))
      |> Enum.sort_by(& &1.paid_at, :asc)

    if Enum.any?(offline_pays) and !PaymentSchedules.all_paid?(job) do
      payment_offline = offline_pays |> List.first() |> Map.get(:paid_at)

      get_date_for_schedule(last_completed_email, payment_offline)
    else
      nil
    end
  end

  def fetch_date_for_state(:before_shoot, email, _last_completed_email, job, _gallery, _order) do
    # Examples
    # shoot.starts_at is ~D[2023-10-20]
    # today is ~D[2023-10-09]
    # difference is 12 days
    # send 7 days before shoot start 12 <= 7 false

    # shoot.starts_at is ~D[2023-10-20]
    # today is ~D[2023-10-13]
    # difference is 7 days
    # send 7 days before shoot start 7<= 7 true

    # shoot.starts_at is ~D[2023-10-20]
    # today is ~D[2023-10-21]
    # difference is 1 days
    # send 1 days before shoot start 1<= 1 true

    timezone = job.client.organization.user.time_zone

    Logger.info("-- before_shoot timezone: #{timezone}")

    today = today_timezone(timezone)

    today_offset_original =
      DateTime.utc_now() |> Timex.end_of_day() |> DateTime.shift_zone!(timezone)

    Logger.info("-- before_shoot today: #{today}")
    Logger.info("-- before_shoot today_offset_original: #{today_offset_original}")

    %{sign: sign} = EmailAutomations.explode_hours(email.total_hours)
    days_to_compare = hours_to_days(email.total_hours)

    shoot = Shoots.get_shoot(email.shoot_id)
    starts_at = shoot.starts_at |> DateTime.shift_zone!(timezone)

    send_time? = is_send_time?(Date.diff(starts_at, today), abs(days_to_compare), sign)
    if send_time?, do: shoot.starts_at, else: nil
  end

  def fetch_date_for_state(:balance_due, _email, last_completed_email, job, _gallery, _order) do
    payment_schedules = PaymentSchedules.payment_schedules(job)
    invoiced_due_date = PaymentSchedules.remainder_due_on(job)

    online_dues =
      payment_schedules
      |> Enum.filter(&(is_nil(&1.paid_at) and &1.type == "stripe"))
      |> Enum.sort_by(& &1.due_at, :asc)

    if is_nil(invoiced_due_date) or Enum.empty?(online_dues) do
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

    if !is_nil(invoiced_due_date) and Enum.any?(offline_dues) do
      due_at = List.first(offline_dues) |> Map.get(:due_at)

      get_date_for_schedule(last_completed_email, due_at)
    else
      nil
    end
  end

  def fetch_date_for_state(:paid_full, _email, last_completed_email, job, _gallery, _order) do
    payment_schedules =
      PaymentSchedules.payment_schedules(job) |> Enum.sort_by(& &1.updated_at, :desc)

    # Trigger when all paid & last payment is paid by stripe
    if Enum.any?(payment_schedules) and PaymentSchedules.all_paid?(job) do
      payment_schedule = payment_schedules |> List.first()
      paid_at = paid_online(payment_schedule)
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
    payment_schedules =
      PaymentSchedules.payment_schedules(job) |> Enum.sort_by(& &1.updated_at, :desc)

    # Trigger when all paid & last payment is paid by cash/check
    if Enum.any?(payment_schedules) and PaymentSchedules.all_paid?(job) do
      payment_schedule = payment_schedules |> List.first()
      paid_at = paid_offline(payment_schedule)
      get_date_for_schedule(last_completed_email, paid_at)
    else
      nil
    end
  end

  def fetch_date_for_state(:shoot_thanks, email, _last_completed_email, job, _gallery, _order) do
    # shoot.starts_at is ~D[2023-10-20]
    # today is ~D[2023-10-09]
    # difference is -12 days
    # send 7 days after shoot -12 >= 7 false

    # shoot.starts_at is ~D[2023-10-20]
    # today is ~D[2023-10-23]
    # difference is 3 days
    # send 7 days after shoot 3 >= 7 false

    # shoot.starts_at is ~D[2023-10-20]
    # today is ~D[2023-10-27]
    # difference is 7 days
    # send 7 days after shoot 7 >= 7 true
    timezone = job.client.organization.user.time_zone
    today = today_timezone(timezone)

    %{sign: sign} = EmailAutomations.explode_hours(email.total_hours)
    days_to_compare = hours_to_days(email.total_hours)

    shoot = Shoots.get_shoot(email.shoot_id)
    starts_at = shoot.starts_at |> DateTime.shift_zone!(timezone)

    send_time? = is_send_time?(Date.diff(today, starts_at), abs(days_to_compare), sign)
    if send_time?, do: shoot.starts_at, else: nil
  end

  def fetch_date_for_state(:post_shoot, email, _last_completed_email, job, _gallery, _order) do
    # shoot.starts_at is ~D[2023-10-20]
    # today is ~D[2023-10-09]
    # difference is -12 days
    # send 7 days after shoot -12 >= 7 false

    # shoot.starts_at is ~D[2023-10-20]
    # today is ~D[2023-10-23]
    # difference is 3 days
    # send 7 days after shoot 3 >= 7 false

    # shoot.starts_at is ~D[2023-10-20]
    # today is ~D[2023-10-27]
    # difference is 7 days
    # send 7 days after shoot 7 >= 7 true

    timezone = job.client.organization.user.time_zone
    today = today_timezone(timezone)

    %{sign: sign} = EmailAutomations.explode_hours(email.total_hours)
    days_to_compare = hours_to_days(email.total_hours)

    filter_shoots_count =
      Enum.count(job.shoots, fn item ->
        starts_at = item.starts_at |> DateTime.shift_zone!(timezone)
        is_send_time?(Date.diff(today, starts_at), abs(days_to_compare), sign)
      end)

    shoots_count = Enum.count(job.shoots)

    if shoots_count == filter_shoots_count and shoots_count >= 1 do
      job.shoots |> List.first() |> Map.get(:starts_at)
    else
      nil
    end
  end

  def fetch_date_for_state(_state, _email, _last_completed_email, _job, _gallery, _order), do: nil

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

  defp today_timezone(timezone) do
    DateTime.utc_now() |> DateTime.shift_zone!(timezone)
  end

  defp get_date_for_schedule(nil, date), do: date
  defp get_date_for_schedule(email, _date), do: email.reminded_at

  defp is_send_time?(days_diff, days_to_compare, "+"), do: days_diff >= days_to_compare
  defp is_send_time?(days_diff, days_to_compare, "-"), do: days_diff <= days_to_compare

  defp get_job_id(job) when is_map(job), do: job.id
  defp get_job_id(_), do: nil
  defp get_gallery_id(gallery, _order) when is_map(gallery), do: gallery.id
  defp get_gallery_id(_gallery, order) when is_map(order), do: order.gallery.id
  defp get_gallery_id(_gallery, _order), do: nil

  defp paid_online(%PaymentSchedule{type: "stripe", paid_at: paid_at}), do: paid_at
  defp paid_online(%PaymentSchedule{type: _type}), do: nil

  defp paid_offline(%PaymentSchedule{type: "stripe"}), do: nil
  defp paid_offline(%PaymentSchedule{type: _type, paid_at: paid_at}), do: paid_at
end
