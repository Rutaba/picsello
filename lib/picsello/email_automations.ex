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
    ClientMessage,
    Galleries,
    Notifiers.ClientNotifier
  }

  alias Picsello.EmailAutomation.{
    EmailAutomationPipeline,
    EmailSchedule
  }

  def get_all_pipelines() do
    from(
      p in EmailAutomationPipeline,
      join: c in assoc(p, :email_automation_category),
      join: s in assoc(p, :email_automation_sub_category),
      select: %{
        category_type: c.type,
        category_name: c.name,
        category_id: c.id,
        subcategory_slug: s.slug,
        subcategory_name: s.name,
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
      order_by: [asc: p.id, asc: c.type, asc: s.slug]
    )
    |> Repo.all()
  end

  def get_schedule_by_id(id) do
    from(es in EmailSchedule, where: es.id == ^id)
    |> Repo.one()
  end

  def get_emails_schedules_by_ids(ids, type) do
    query =
      from(
        es in EmailSchedule,
        join: p in assoc(es, :email_automation_pipeline),
        join: c in assoc(p, :email_automation_category),
        select: %{
          category_type: c.type,
          category_id: c.id,
          pipeline:
            fragment(
              "to_jsonb(json_build_object('id', ?, 'name', ?, 'state', ?, 'description', ?, 'email', ?))",
              p.id,
              p.name,
              p.state,
              p.description,
              fragment(
                "to_jsonb(json_build_object('id', ?, 'name', ?, 'total_hours', ?, 'condition', ?, 'body_template', ?, 'subject_template', ?, 'private_name', ?, 'is_stopped', ?, 'reminded_at', ?))",
                es.id,
                es.name,
                es.total_hours,
                es.condition,
                es.body_template,
                es.private_name,
                es.private_name,
                es.is_stopped,
                es.reminded_at
              )
            )
        }
      )

    query
    |> filter_email_schedule(ids, type)
    |> Repo.all()
    |> email_schedules_group_by_categories()
  end

  defp filter_email_schedule(query, galleries, :gallery) do
    query
    |> join(:inner, [es, _, _], g in assoc(es, :gallery))
    |> where([es, _, _, _], es.gallery_id in ^galleries)
    |> select_merge([_, _, c, g], %{
      category_name: fragment("concat(?, ':', ?)", c.name, g.name),
      gallery_id: g.id
    })
    |> group_by([es, p, c, g], [c.name, g.name, c.type, c.id, p.id, es.id, g.id])
  end

  defp filter_email_schedule(query, job_id, _type) do
    query
    |> where([es, _, _], es.job_id == ^job_id)
    |> select_merge([_, _, c], %{category_name: c.name, gallery_id: nil})
    |> group_by([es, p, c], [c.name, c.type, c.id, p.id, es.id])
  end

  defp email_schedules_group_by_categories(emails_schedules) do
    emails_schedules
    |> Enum.group_by(&{&1.category_id, &1.category_name, &1.category_type, &1.gallery_id})
    |> Enum.map(fn {{category_id, category_name, category_type, gallery_id}, group} ->
      pipelines =
        group
        |> Enum.group_by(& &1.pipeline["id"])
        |> Enum.map(fn {_pipeline_id, pipelines} ->
          emails =
            pipelines
            |> Enum.map(& &1.pipeline["email"])

          map = Map.delete(List.first(pipelines).pipeline, "email")
          Map.put(map, "emails", emails)
        end)

      pipeline_morphied = pipelines |> Enum.map(&(&1 |> Morphix.atomorphiform!()))

      %{
        category_id: category_id,
        category_name: category_name,
        category_type: category_type,
        gallery_id: gallery_id,
        pipelines: pipeline_morphied
      }
    end)
    |> Enum.sort_by(&{&1.category_id, &1.category_name}, :asc)
  end

  def get_pipeline_states_type(type) do
    from(p in EmailAutomationPipeline,
      join: c in assoc(p, :email_automation_category),
      where: c.type == ^type,
      select: p.state
    )
  end

  def get_all_emails_schedules() do
    from(es in EmailSchedule)
    |> preload(email_automation_pipeline: [:email_automation_category])
    |> Repo.all()
  end

  def get_subjects_for_job_pipeline(emails) do
    emails
    |> Enum.map(& &1.subject_template)
  end

  def get_job(nil), do: nil

  def get_job(id),
    do:
      Jobs.get_job_by_id(id)
      |> Repo.preload([
        :booking_proposals,
        :booking_event,
        :payment_schedules,
        :job_status,
        client: :organization
      ])

  def fetch_date_for_state(state, nil), do: nil

  @doc """
    Runs after a contact/lead form submission
    Get job submitted date
  """
  def fetch_date_for_state(state, job)
      when state in [
             :client_contact,
             :pays_retainer,
             :booking_event,
             :gallery_send_link,
             :cart_abandoned,
             :gallery_expiration_soon,
             :gallery_password_changed
           ] do
    job |> Map.get(:inserted_at)
  end

  @doc """
    Starts when client pays their first payment or retainer
    Get first payment submitted date which is paid
  """
  def fetch_date_for_state(state, job)
      when state in [:before_shoot, :balance_due, :shoot_thanks] do
    job
    |> Map.get(:payment_schedules)
    |> Enum.sort_by(& &1.id)
    |> Enum.filter(fn schedule -> schedule.paid_at != nil end)
    |> List.first()
    |> case do
      nil -> nil
      payment_schedule -> payment_schedule |> Map.get(:inserted_at)
    end
  end

  @doc """
    Starts when client completes a booking event
    Get booking event submitted date
  """
  def fetch_date_for_state(state, job)
      when state in [:paid_full, :offline_payment, :post_shoot] do
    job
    |> Map.get(:booking_event)
    |> case do
      nil -> nil
      booking_event -> booking_event |> Map.get(:inserted_at)
    end
  end

  @doc """
    Runs after finishing and sending the proposal
    Get first booking_proposal send date
  """
  def fetch_date_for_state(state, job) when state == :booking_proposal_sent do
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

  @doc """
  Catch-all clause to handle any other input patterns
  """
  def fetch_date_for_state(_state, _job), do: nil

  def is_email_send_time(nil, _total_hours), do: false

  def is_email_send_time(submit_time, total_hours) do
    {:ok, current_time} = DateTime.now("Etc/UTC")
    diff_seconds = DateTime.diff(current_time, submit_time, :second)
    hours = div(diff_seconds, 3600)
    if hours >= total_hours, do: true, else: false
  end

  def get_emails_for_schedule(organization_id, job_type, types \\ [:lead]) do
    from(
      ep in EmailPreset,
      join: eap in EmailAutomationPipeline,
      on: eap.id == ep.email_automation_pipeline_id,
      join: eac in assoc(eap, :email_automation_category),
      where: ep.organization_id == ^organization_id
      and ep.job_type == ^job_type
      and ep.status == :active
      and eac.type in ^types
    )
    |> Repo.all()
  end

  def get_pipeline_by_id(id) do
    from(eap in EmailAutomationPipeline, where: eap.id == ^id)
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

  def get_each_pipeline_emails(pipeline_id, organization_id, job_type) do
    from(
      ep in EmailPreset,
      where:
        ep.email_automation_pipeline_id == ^pipeline_id and ep.organization_id == ^organization_id,
      where: ep.job_type == ^job_type,
      order_by: [asc: ep.id]
    )
    |> Picsello.Repo.all()
  end

  def get_email_by_id(id) do
    from(
      ep in EmailPreset,
      where: ep.id == ^id
    )
    |> Repo.one()
  end

  def get_email_schedule_by_id(id) do
    from(es in EmailSchedule, where: es.id == ^id)
    |> Repo.one()
  end

  def update_email_schedule(id, params) do
    get_email_schedule_by_id(id)
    |> EmailSchedule.changeset(params)
    |> Repo.update()
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

  def group_by_sub_category(automation_pipelines) do
    automation_pipelines
    |> Enum.group_by(&{&1.subcategory_slug, &1.subcategory_name, &1.subcategory_id})
    |> Enum.map(fn {{slug, name, id}, automation_pipelines} ->
      %{
        category_type: List.first(automation_pipelines).category_type,
        category_name: List.first(automation_pipelines).category_name,
        category_id: List.first(automation_pipelines).category_id,
        subcategory_slug: slug,
        subcategory_name: name,
        subcategory_id: id,
        pipelines: automation_pipelines |> Enum.flat_map(& &1.pipelines)
      }
    end)
    |> Enum.sort_by(& &1.subcategory_id, :asc)
    |> Enum.group_by(&{&1.category_type, &1.category_name, &1.category_id}, & &1)
    |> Enum.map(fn {{type, name, id}, pipelines} ->
      subcategories = remove_categories_from_list(pipelines)
      %{category_type: type, category_name: name, category_id: id, subcategories: subcategories}
    end)
    |> Enum.sort_by(& &1.category_type, :desc)
  end

  def resolve_variables(%EmailSchedule{} = preset, schemas, helpers) do
    resolver_module =
      case preset.email_automation_pipeline.email_automation_category.type do
        :gallery -> Picsello.EmailPresets.GalleryResolver
        _ -> Picsello.EmailPresets.JobResolver
      end

    resolver = schemas |> resolver_module.new(helpers)

    data =
      for {key, func} <- resolver_module.vars(), into: %{} do
        {key, func.(resolver)}
      end

    %{
      preset
      | body_template: Utils.render(preset.body_template, data),
        subject_template: Utils.render(preset.subject_template, data)
    }
  end

  def resolve_all_subjects(job, gallery, type, subjects) do
    schema = if is_nil(gallery), do: job, else: gallery

    Enum.map(subjects, fn subject ->
      resolve_variables_for_subject(schema, type, subject)
    end)
  end

  defp resolve_variables_for_subject(job, type, subject) do
    schemas = {job}

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

  def send_now_email(:gallery, email, gallery, state)
      when state in [
             :gallery_send_link,
             :cart_abandoned,
             :gallery_expiration_soon,
             :gallery_password_changed
           ] do
    gallery = gallery |> Galleries.set_gallery_hash() |> Repo.preload([:albums, job: :client])

    schema_gallery = schemas(gallery)

    ClientNotifier.deliver_automation_email_gallery(
      email,
      gallery,
      schema_gallery,
      state,
      PicselloWeb.Helpers
    )
    |> update_schedule(email.id)
  end

  def send_now_email(type, email, job, state) when type in [:lead, :job] do
    ClientNotifier.deliver_automation_email_job(email, job, {job}, state, PicselloWeb.Helpers)
    |> update_schedule(email.id)
  end

  def send_now_email(_type, _email, _order, _state) do
    {:ok, nil}
  end

  def update_schedule(result, id) do
    case result do
      {:ok, _} ->
        update_email_schedule(id, %{
          reminded_at: DateTime.truncate(DateTime.utc_now(), :second)
        })

      error ->
        error
    end
  end

  defp schemas(%{type: :standard} = gallery), do: {gallery}
  defp schemas(%{albums: [album]} = gallery), do: {gallery, album}

  def is_reply_receive!(job, subjects) do
    get_client_messages(job, subjects)
    |> Enum.count() > 0
  end

  def get_client_messages(nil, _subjects), do: []

  def get_client_messages(job, subjects) do
    from(
      c in ClientMessage,
      join: r in assoc(c, :client_message_recipients),
      on: c.id == r.client_message_id,
      where: c.subject in ^subjects and c.job_id == ^job.id and c.outbound == false,
      where: r.client_id == ^job.client.id and r.recipient_type == :to
    )
    |> Repo.all()
  end

  def query_get_email_schedule(category_type, gallery_id, job_id, piepline_id) do
    query =
      from(es in EmailSchedule,
        where: es.email_automation_pipeline_id == ^piepline_id,
        limit: 1
      )

    case category_type do
      :gallery -> query |> where([es], es.gallery_id == ^gallery_id)
      _ -> query |> where([es], es.job_id == ^job_id)
    end
  end

  defp remove_categories_from_list(sub_categories) do
    Enum.map(sub_categories, fn sub_category ->
      sub_category
      |> Map.take([:pipelines, :subcategory_id, :subcategory_slug, :subcategory_name])
    end)
  end

  defp toggle_status("true"), do: "disabled"
  defp toggle_status("false"), do: "active"
end

# Picsello.EmailAutomations.get_emails_schedules(119, :job)
# Picsello.EmailAutomations.filter_emails_on_time_schedule()
# # Picsello.EmailAutomations.get_emails_schedules_for_job_pipeline(119, nil, 1)
# Picsello.EmailAutomations.get_client_messages(88)
