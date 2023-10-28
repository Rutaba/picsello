defmodule Picsello.EmailAutomations do
  @moduledoc """
    context module for email automation
  """
  import Ecto.Query

  alias Picsello.{
    Repo,
    EmailPresets.EmailPreset,
    Utils,
    Jobs,
    Galleries,
    Orders,
    EmailAutomationSchedules,
    Notifiers.EmailAutomationNotifier,
    EmailPresets,
    PaymentSchedule,
    PaymentSchedules
  }

  alias Picsello.EmailAutomation.{
    EmailAutomationPipeline,
    EmailAutomationSubCategory
  }

  def get_emails_for_schedule(organization_id, job_type, type, skip_sub_categories \\ [""]) do
    from(
      ep in EmailPreset,
      # distinct: ep.name,
      join: eap in EmailAutomationPipeline,
      on: eap.id == ep.email_automation_pipeline_id,
      join: eac in assoc(eap, :email_automation_category),
      join: eas in assoc(eap, :email_automation_sub_category),
      # order_by: [desc: ep.id],
      where:
        ep.organization_id == ^organization_id and
          ep.job_type == ^job_type and
          ep.status == :active and
          eac.type == ^type and
          eas.slug not in ^skip_sub_categories
    )
    |> preload(:email_automation_pipeline)
    |> Repo.all()
  end

  def get_sub_categories() do
    from(EmailAutomationSubCategory) |> Repo.all()
  end

  def get_pipeline_by_id(id) do
    from(eap in EmailAutomationPipeline, where: eap.id == ^id)
    |> Repo.one()
  end

  def get_pipeline_by_state(state) do
    from(eap in EmailAutomationPipeline, where: eap.state == ^state)
    |> Repo.one()
  end

  def update_pipeline_and_settings_status(pipeline_id, active) do
    status = toggle_status(active)

    from(es in EmailPreset,
      where: es.email_automation_pipeline_id == ^pipeline_id,
      update: [set: [status: ^status]]
    )
    |> Repo.update_all([])
  end

  def delete_email(email_preset_id) do
    from(p in EmailPreset,
      where: p.id == ^email_preset_id
    )
    |> Repo.one()
    |> Repo.delete()
  end

  def get_email_by_id(id) do
    from(
      ep in EmailPreset,
      where: ep.id == ^id
    )
    |> Repo.one()
  end

  def get_all_pipelines_emails(organization_id, job_type) do
    get_all_pipelines()
    |> Enum.map(fn %{pipelines: pipelines} = automation ->
      updated_pipelines =
        Enum.map(pipelines, fn pipeline ->
          pipeline_morphed = pipeline |> Morphix.atomorphiform!()
          pipeline_id = Map.get(pipeline_morphed, :id)
          emails_data = get_each_pipeline_emails(pipeline_id, organization_id, job_type)
          # Update pipeline struct with email data
          Map.put(pipeline_morphed, :emails, emails_data)
        end)

      Map.put(automation, :pipelines, updated_pipelines)
    end)
    |> group_by_sub_category()
  end

  def get_order(nil), do: nil

  def get_order(id),
    do:
      Orders.get_order(id)
      |> Repo.preload([:digitals, gallery: :job])

  def get_gallery(nil), do: nil

  def get_gallery(id) do
    case Galleries.get_gallery(id) do
      nil -> nil
      result -> result |> Repo.preload([:orders, :albums, job: :client])
    end
  end

  def get_job(nil), do: nil

  def get_job(id),
    do:
      Jobs.get_job_by_id(id)
      |> Repo.preload([
        :shoots,
        :booking_proposals,
        :booking_event,
        :payment_schedules,
        :job_status,
        client: :organization
      ])

  def resolve_variables(preset, schemas, helpers) do
    resolver_module =
      case preset.email_automation_pipeline.email_automation_category.type do
        :gallery -> Picsello.EmailPresets.GalleryResolver
        _ -> Picsello.EmailPresets.JobResolver
      end

    resolver = schemas |> resolver_module.new(helpers)

    %{calendar: calendar, count: count, sign: sign} = get_email_meta(preset.total_hours, helpers)

    total_time =
      "#{count} #{calendar} #{sign}"
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)

    total_time = if total_time == "1 Day Before", do: "tomorrow", else: total_time

    data =
      for {key, func} <- resolver_module.vars(), into: %{} do
        {key, func.(resolver)}
      end
      |> Map.put("total_time", total_time)

    %{
      preset
      | body_template:
          Utils.render(preset.body_template, data) |> Utils.normalize_body_template(),
        subject_template: Utils.render(preset.subject_template, data)
    }
  end

  def resolve_all_subjects(job, gallery, type, subjects) do
    schema = if is_nil(gallery), do: job, else: gallery

    Enum.map(subjects, fn subject ->
      resolve_variables_for_subject(schema, type, subject)
    end)
  end

  def send_now_email(:gallery, email, gallery, state)
      when state in [
             :manual_gallery_send_link,
             :manual_send_proofing_gallery,
             :manual_send_proofing_gallery_finals,
             :cart_abandoned,
             :gallery_expiration_soon,
             :gallery_password_changed,
             :after_gallery_send_feedback
           ] do
    gallery = gallery |> Galleries.set_gallery_hash() |> Repo.preload([:albums, job: :client])

    schema_gallery = schemas(gallery)

    EmailAutomationNotifier.Impl.deliver_automation_email_gallery(
      email,
      gallery,
      schema_gallery,
      state,
      PicselloWeb.Helpers
    )
    |> update_schedule(email.id)
  end

  def send_now_email(:order, email, order, state) do
    order = order |> Repo.preload(gallery: :job)

    EmailAutomationNotifier.Impl.deliver_automation_email_order(
      email,
      order,
      {order, order.gallery},
      state,
      PicselloWeb.Helpers
    )
    |> update_schedule(email.id)
  end

  def send_now_email(type, email, job, state) when type in [:lead, :job] do
    payment_schedule =
      PaymentSchedule
      |> where([ps], ps.job_id == ^job.id and not is_nil(ps.paid_at))
      |> order_by(desc: :updated_at)
      |> limit(1)
      |> Repo.one()
      |> then(fn
        %PaymentSchedule{} = ps ->
          ps

        nil ->
          currency = Picsello.Currency.for_job(job)
          %PaymentSchedule{price: Money.new(0, currency)}
      end)

    EmailAutomationNotifier.Impl.deliver_automation_email_job(
      email,
      job,
      {job, payment_schedule},
      state,
      PicselloWeb.Helpers
    )
    |> update_schedule(email.id)
  end

  defp get_all_pipelines() do
    from(
      p in EmailAutomationPipeline,
      join: c in assoc(p, :email_automation_category),
      join: s in assoc(p, :email_automation_sub_category),
      select: %{
        category_type: c.type,
        category_name: c.name,
        category_position: c.position,
        category_id: c.id,
        subcategory_slug: s.slug,
        subcategory_name: s.name,
        subcategory_position: s.position,
        subcategory_id: s.id,
        pipelines:
          fragment(
            "array_agg(to_jsonb(json_build_object('id', ?, 'name', ?, 'state', ?, 'description', ?)))",
            p.id,
            p.name,
            p.state,
            p.description
          )
      },
      group_by: [c.name, c.type, c.id, s.slug, s.name, s.id, p.id],
      order_by: [asc: p.position, asc: c.type, asc: s.slug]
    )
    |> Repo.all()
  end

  defp group_by_sub_category(automation_pipelines) do
    automation_pipelines
    |> Enum.group_by(
      &{&1.subcategory_slug, &1.subcategory_name, &1.subcategory_id, &1.subcategory_position}
    )
    |> Enum.map(fn {{slug, name, id, position}, automation_pipelines} ->
      %{
        category_type: List.first(automation_pipelines).category_type,
        category_name: List.first(automation_pipelines).category_name,
        category_id: List.first(automation_pipelines).category_id,
        category_position: List.first(automation_pipelines).category_position,
        subcategory_slug: slug,
        subcategory_name: name,
        subcategory_id: id,
        subcategory_position: position,
        pipelines: automation_pipelines |> Enum.flat_map(& &1.pipelines)
      }
    end)
    |> Enum.sort_by(& &1.subcategory_position, :asc)
    |> Enum.group_by(
      &{&1.category_type, &1.category_name, &1.category_id, &1.category_position},
      & &1
    )
    |> Enum.map(fn {{type, name, id, position}, pipelines} ->
      subcategories = remove_categories_from_list(pipelines)

      %{
        category_type: type,
        category_name: name,
        category_id: id,
        category_position: position,
        subcategories: subcategories
      }
    end)
    |> Enum.sort_by(& &1.category_position, :asc)
  end

  defp update_schedule(result, id) do
    case result do
      {:ok, _} ->
        EmailAutomationSchedules.update_email_schedule(id, %{
          reminded_at: DateTime.truncate(DateTime.utc_now(), :second)
        })

      error ->
        error
    end
  end

  def remove_categories_from_list(sub_categories) do
    Enum.map(sub_categories, fn sub_category ->
      sub_category
      |> Map.take([:pipelines, :subcategory_id, :subcategory_slug, :subcategory_name])
    end)
  end

  defp toggle_status("true"), do: "disabled"
  defp toggle_status("false"), do: "active"

  defp resolve_variables_for_subject(schema, type, subject) do
    schemas = {schema}

    resolver_module =
      case type do
        :gallery -> Picsello.EmailPresets.GalleryResolver
        _ -> Picsello.EmailPresets.JobResolver
      end

    resolver = schemas |> resolver_module.new(PicselloWeb.Helpers)

    data =
      for {key, func} <- resolver_module.vars(), into: %{} do
        {key, func.(resolver)}
      end

    Utils.render(subject, data)
  end

  defp get_each_pipeline_emails(pipeline_id, organization_id, job_type) do
    from(
      ep in EmailPreset,
      where:
        ep.email_automation_pipeline_id == ^pipeline_id and
          ep.organization_id == ^organization_id and
          ep.job_type == ^job_type
    )
    |> Picsello.Repo.all()
  end

  defp schemas(%{type: :standard} = gallery), do: {gallery}
  defp schemas(%{albums: [album]} = gallery), do: {gallery, album}

  def get_email_meta(hours, helpers) do
    %{calendar: calendar, count: count, sign: sign} = explode_hours(hours)
    sign = if sign == "+", do: "after", else: "before"
    calendar = calendar_text(calendar, count, helpers)

    %{calendar: calendar, count: count, sign: sign}
  end

  defp calendar_text("Hour", count, helpers), do: helpers.ngettext("hour", "hours", count)
  defp calendar_text("Day", count, helpers), do: helpers.ngettext("day", "days", count)
  defp calendar_text("Month", count, helpers), do: helpers.ngettext("month", "months", count)
  defp calendar_text("Year", count, helpers), do: helpers.ngettext("year", "years", count)

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

  def send_pays_retainer(job, state, organization_id) do
    if !PaymentSchedules.all_paid?(job) do
      pipeline = get_pipeline_by_state(state)

      email_schedule =
        get_email_from_schedule(
          job.id,
          pipeline.id,
          state,
          PicselloWeb.EmailAutomationLive.Shared
        )
        |> preload_email()

      email_preset =
        EmailPresets.user_email_automation_presets(
          :job,
          job.type,
          pipeline.id,
          organization_id
        )
        |> List.first()
        |> preload_email()

      send_payment_email(email_schedule, email_preset, job, state)
    end
  end

  defp send_payment_email(nil, email_preset, job, state) do
    EmailAutomationNotifier.Impl.deliver_automation_email_job(
      email_preset,
      job,
      {job},
      state,
      PicselloWeb.Helpers
    )
  end

  defp send_payment_email(email_schedule, _email_preset, job, state) do
    EmailAutomationNotifier.Impl.deliver_automation_email_job(
      email_schedule,
      job,
      {job},
      state,
      PicselloWeb.Helpers
    )

    EmailAutomationSchedules.update_email_schedule(email_schedule.id, %{
      reminded_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  defp get_email_from_schedule(job_id, pipeline_id, state, helpers) do
    EmailAutomationSchedules.query_get_email_schedule(
      :job,
      nil,
      job_id,
      pipeline_id
    )
    |> where([es], is_nil(es.reminded_at))
    |> where([es], is_nil(es.stopped_at))
    |> Repo.all()
    |> helpers.sort_emails(state)
    |> List.first()
  end

  defp preload_email(email),
    do: email |> Repo.preload(email_automation_pipeline: [:email_automation_category])
end
