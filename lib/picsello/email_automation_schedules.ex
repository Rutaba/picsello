defmodule Picsello.EmailAutomationSchedules do
  @moduledoc """
    context module for email automation
  """
  import Ecto.Query

  alias Picsello.{
    Repo,
    EmailAutomations,
    EmailAutomation.EmailSchedule,
    EmailAutomation.EmailScheduleHistory,
    Galleries
  }

  def get_schedule_by_id(id) do
    from(es in EmailSchedule, where: es.id == ^id)
    |> Repo.one()
  end

  def get_emails_by_gallery(table, gallery_id, type) do
    from(es in table, where: es.gallery_id == ^gallery_id and es.type == ^type)
    |> Repo.all()
  end

  def get_emails_by_order(table, order_id, type) do
    from(es in table, where: es.order_id == ^order_id and es.type == ^type)
    |> Repo.all()
  end

  def get_emails_by_job(table, job_id, type) do
    from(es in table, where: es.job_id == ^job_id and es.type == ^type)
    |> Repo.all()
  end

  def get_emails_by_shoot(table, shoot_id, type) do
    from(es in table, where: es.shoot_id == ^shoot_id and es.type == ^type)
    |> Repo.all()
  end

  def get_active_email_schedule_count(job_id) do
    job_count =
      from(es in EmailSchedule,
        where:
          is_nil(es.stopped_at) and is_nil(es.reminded_at) and es.job_id == ^job_id and
            is_nil(es.gallery_id)
      )
      |> Repo.aggregate(:count)

    active_gallery_ids =
      Galleries.get_galleries_by_job_id(job_id) |> Enum.map(fn gallery -> gallery.id end)

    active_galleries_count =
      from(es in EmailSchedule,
        where:
          is_nil(es.stopped_at) and is_nil(es.reminded_at) and es.job_id == ^job_id and
            es.gallery_id in ^active_gallery_ids
      )
      |> Repo.aggregate(:count)

    job_count + active_galleries_count
  end

  def get_email_schedules_by_ids(ids, type) do
    email_schedule_query =
      from(
        es in EmailSchedule,
        join: p in assoc(es, :email_automation_pipeline),
        join: c in assoc(p, :email_automation_category),
        join: s in assoc(p, :email_automation_sub_category)
      )
      |> select_schedule_fields()
      |> filter_email_schedule(ids, type)

    union_query =
      from(
        history in EmailScheduleHistory,
        join: pipeline in assoc(history, :email_automation_pipeline),
        join: category in assoc(pipeline, :email_automation_category),
        join: subcategory in assoc(pipeline, :email_automation_sub_category),
        union_all: ^email_schedule_query
      )
      |> select_schedule_fields()
      |> filter_email_schedule(ids, type)

    union_query
    |> Repo.all()
    |> email_schedules_group_by_categories()
  end

  defp select_schedule_fields(query) do
    query
    |> select([email, pipeline, category, subcategory], %{
      category_type: category.type,
      category_id: category.id,
      category_position: category.position,
      subcategory_slug: subcategory.slug,
      subcategory_id: subcategory.id,
      subcategory_position: subcategory.position,
      job_id: email.job_id,
      pipeline:
        fragment(
          "to_jsonb(json_build_object('id', ?, 'name', ?, 'state', ?, 'description', ?, 'email', ?))",
          pipeline.id,
          pipeline.name,
          pipeline.state,
          pipeline.description,
          fragment(
            "to_jsonb(json_build_object('id', ?, 'name', ?, 'total_hours', ?, 'condition', ?, 'body_template', ?, 'subject_template', ?, 'private_name', ?, 'stopped_at', ?, 'reminded_at', ?, 'shoot_id', ?, 'order_id', ?, 'gallery_id', ?, 'job_id', ?))",
            email.id,
            email.name,
            email.total_hours,
            email.condition,
            email.body_template,
            email.private_name,
            email.private_name,
            email.stopped_at,
            email.reminded_at,
            email.shoot_id,
            email.order_id,
            email.gallery_id,
            email.job_id
          )
        )
    })
  end

  def get_all_emails_schedules(organizations) do
    from(es in EmailSchedule, where: es.organization_id in ^organizations)
    |> preload(email_automation_pipeline: [:email_automation_category])
    |> Repo.all()
  end

  def update_email_schedule(id, %{reminded_at: _reminded_at} = params) do
    schedule = get_schedule_by_id(id)

    history_params =
      schedule
      |> Map.drop([
        :__meta__,
        :__struct__,
        :email_automation_pipeline,
        :gallery,
        :job,
        :order,
        :organization
      ])
      |> Map.merge(params)

    multi_schedule =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :email_schedule_history,
        EmailScheduleHistory.changeset(history_params)
      )
      |> Ecto.Multi.delete(:delete_email_schedule, schedule)
      |> Repo.transaction()

    with {:ok, multi} <- multi_schedule,
         _count <- EmailAutomations.broadcast_count_of_emails(schedule.job_id) do
      {:ok, multi}
    else
      error -> error
    end
  end

  def update_email_schedule(id, params) do
    get_schedule_by_id(id)
    |> EmailSchedule.changeset(params)
    |> Repo.update()
  end

  defp filter_email_schedule(query, galleries, :gallery) do
    query
    |> join(:inner, [es, _, _, _], gallery in assoc(es, :gallery))
    |> join(:left, [es, _, _, _, gallery], order in assoc(es, :order))
    |> where([es, _, _, _, _, _], es.gallery_id in ^galleries)
    |> select_merge([es, _, c, s, gallery, order], %{
      category_name: fragment("concat(?, ':', ?)", c.name, gallery.name),
      gallery_id: gallery.id,
      order_id: es.order_id,
      shoot_id: nil,
      order_number: order.number,
      subcategory_name: fragment("concat(?, ':', ?)", s.name, order.number)
    })
    |> group_by([es, p, c, s, gallery, order], [
      c.name,
      gallery.name,
      c.type,
      c.id,
      p.id,
      es.id,
      es.order_id,
      gallery.id,
      s.id,
      s.slug,
      s.name,
      order.number
    ])
  end

  defp filter_email_schedule(query, job_id, _type) do
    query
    |> where([es, _, _, _], es.job_id == ^job_id)
    |> where([es, _, _, _], is_nil(es.gallery_id))
    |> join(:left, [es, _, _, _], shoot in assoc(es, :shoot))
    |> select_merge([_, _, c, s, shoot], %{
      category_name: c.name,
      subcategory_name:
        fragment(
          "CASE WHEN ? IS NOT NULL THEN concat(?, ':', ?) ELSE ? END",
          shoot.name,
          s.name,
          shoot.name,
          s.name
        ),
      shoot_id: shoot.id,
      gallery_id: nil,
      order_id: nil,
      order_number: ""
    })
    |> group_by([es, p, c, s, shoot], [
      c.name,
      c.type,
      c.id,
      p.id,
      es.id,
      s.id,
      s.slug,
      s.name,
      shoot.id
    ])
  end

  defp email_schedules_group_by_categories(emails_schedules) do
    emails_schedules
    |> Enum.group_by(
      &{&1.subcategory_slug, &1.subcategory_name, &1.subcategory_id, &1.subcategory_position,
       &1.gallery_id, &1.job_id, &1.order_id, &1.shoot_id, &1.order_number}
    )
    |> Enum.map(fn {{slug, name, id, position, gallery_id, job_id, order_id, shoot_id,
                     order_number}, automation_pipelines} ->
      pipelines =
        automation_pipelines
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
        category_type: List.first(automation_pipelines).category_type,
        category_name: List.first(automation_pipelines).category_name,
        category_id: List.first(automation_pipelines).category_id,
        category_position: List.first(automation_pipelines).category_position,
        subcategory_slug: slug,
        subcategory_name: name,
        subcategory_id: id,
        subcategory_position: position,
        shoot_id: shoot_id,
        gallery_id: gallery_id,
        job_id: job_id,
        order_id: order_id,
        order_number: order_number,
        pipelines: pipeline_morphied
      }
    end)
    |> Enum.sort_by(&{&1.subcategory_position, &1.subcategory_name}, :asc)
    |> Enum.group_by(
      &{&1.category_id, &1.category_name, &1.category_type, &1.category_position, &1.gallery_id,
       &1.job_id}
    )
    |> Enum.map(fn {{id, name, type, position, gallery_id, job_id}, pipelines} ->
      subcategories = EmailAutomations.remove_categories_from_list(pipelines)

      %{
        category_type: type,
        category_name: name,
        category_id: id,
        category_position: position,
        gallery_id: gallery_id,
        job_id: job_id,
        subcategories: subcategories
      }
    end)
    |> Enum.sort_by(&{&1.category_position, &1.category_name}, :asc)
  end

  def query_get_email_schedule(
        category_type,
        gallery_id,
        shoot_id,
        job_id,
        piepline_id,
        table \\ EmailSchedule
      ) do
    query = from(es in table, where: es.email_automation_pipeline_id == ^piepline_id)

    case category_type do
      :gallery -> query |> where([es], es.gallery_id == ^gallery_id)
      :shoot -> query |> where([es], es.shoot_id == ^shoot_id)
      _ -> query |> where([es], es.job_id == ^job_id)
    end
  end

  def get_last_completed_email(
        category_type,
        gallery_id,
        shoot_id,
        job_id,
        pipeline_id,
        state,
        helpers
      ) do
    query_get_email_schedule(
      category_type,
      gallery_id,
      shoot_id,
      job_id,
      pipeline_id,
      EmailScheduleHistory
    )
    |> where([es], not is_nil(es.reminded_at))
    |> Repo.all()
    |> helpers.sort_emails(state)
    |> List.last()
  end

  @doc """
    Insert all emails templates for jobs & leads in email schedules
  """
  def job_emails(type, organization_id, job_id, category_type, skip_states \\ []) do
    shoot_skip_states = [:before_shoot, :shoot_thanks]
    all_skip_states = skip_states ++ shoot_skip_states
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    emails =
      EmailAutomations.get_emails_for_schedule(organization_id, type, category_type)
      |> Enum.map(fn email_data ->
        state = Map.get(email_data, :email_automation_pipeline) |> Map.get(:state)

        if state not in all_skip_states do
          [
            job_id: job_id,
            shoot_id: nil,
            type: category_type,
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

    previous_emails_schedules = get_emails_by_job(EmailSchedule, job_id, category_type)

    previous_emails_history = get_emails_by_job(EmailScheduleHistory, job_id, category_type)

    if Enum.empty?(previous_emails_schedules) and Enum.empty?(previous_emails_history) do
      emails
    else
      []
    end
  end

  def shoot_emails(job, shoot) do
    job = job |> Repo.preload(client: [organization: [:user]])
    category_type = :shoot

    skip_sub_categories = [
      "post_job_emails",
      "payment_reminder_emails",
      "booking_response_emails"
    ]

    organization_id = job.client.organization.id
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    emails =
      EmailAutomations.get_emails_for_schedule(
        job.client.organization.id,
        job.type,
        :job,
        skip_sub_categories
      )
      |> Enum.map(fn email_data ->
        state = Map.get(email_data, :email_automation_pipeline) |> Map.get(:state)

        if state not in [:post_shoot] do
          [
            shoot_id: shoot.id,
            gallery_id: nil,
            type: category_type,
            order_id: nil,
            job_id: job.id,
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

    previous_emails_schedules = get_emails_by_shoot(EmailSchedule, shoot.id, category_type)

    previous_emails_history = get_emails_by_shoot(EmailScheduleHistory, shoot.id, category_type)

    if Enum.empty?(previous_emails_schedules) and Enum.empty?(previous_emails_history) do
      emails
    else
      []
    end
  end

  def insert_shoot_emails(job, shoot) do
    emails = shoot_emails(job, shoot)

    case Repo.insert_all(EmailSchedule, emails) do
      {count, nil} -> {:ok, count}
      _ -> {:error, "error insertion"}
    end
  end

  def insert_job_emails_from_gallery(gallery, type) do
    gallery =
      gallery
      |> Repo.preload([:job, organization: [organization_job_types: :jobtype]], force: true)

    job_type = gallery.job.type
    organization_id = gallery.organization.id
    job_emails(job_type, organization_id, gallery.job.id, type)
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

    skip_sub_categories =
      if order,
        do: ["gallery_notification_emails", "post_gallery_send_emails", "order_status_emails"],
        else: ["order_confirmation_emails", "order_status_emails"]

    order_id = if order, do: order.id, else: nil
    category_type = if order, do: :order, else: :gallery

    emails =
      EmailAutomations.get_emails_for_schedule(
        gallery.organization.id,
        type,
        :gallery,
        skip_sub_categories
      )
      |> email_mapping(gallery, category_type, order_id)
      |> Enum.filter(&(&1 != nil))

    previous_emails =
      if order,
        do: get_emails_by_order(EmailSchedule, order.id, category_type),
        else: get_emails_by_gallery(EmailSchedule, gallery.id, category_type)

    previous_emails_history =
      if order,
        do: get_emails_by_order(EmailScheduleHistory, order.id, category_type),
        else: get_emails_by_gallery(EmailScheduleHistory, gallery.id, category_type)

    if Enum.empty?(previous_emails) and Enum.empty?(previous_emails_history) do
      emails
    else
      []
    end
  end

  def insert_gallery_order_emails(gallery, order) do
    emails = gallery_order_emails(gallery, order)

    case Repo.insert_all(EmailSchedule, emails) do
      {count, nil} -> {:ok, count}
      _ -> {:error, "error insertion"}
    end
  end

  def insert_job_emails(type, organization_id, job_id, category_type, skip_states \\ []) do
    emails = job_emails(type, organization_id, job_id, category_type, skip_states)

    case Repo.insert_all(EmailSchedule, emails) do
      {count, nil} -> {:ok, count}
      _ -> {:error, "error insertion"}
    end
  end

  defp email_mapping(data, gallery, category_type, order_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    data
    |> Enum.map(fn email_data ->
      state = Map.get(email_data, :email_automation_pipeline) |> Map.get(:state)

      if state not in [
           :gallery_password_changed,
           :order_confirmation_physical,
           :order_confirmation_digital
         ] do
        [
          gallery_id: gallery.id,
          type: category_type,
          order_id: order_id,
          job_id: gallery.job.id,
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
  end
end
