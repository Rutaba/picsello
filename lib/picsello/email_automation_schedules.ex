defmodule Picsello.EmailAutomationSchedules do
  @moduledoc """
  This module provides functions for managing email automation schedules.

  The Picsello.EmailAutomationSchedules module is a context module for handling email automation schedules within the Picsello application.
  It provides functions for retrieving, updating, and managing email schedules and related data. These functions are used in the context of
  email automation, which allows organizations to send automated emails to clients based on predefined criteria.

  ## Functions

      - `get_schedule_by_id(id)`: Retrieve an email automation schedule by its ID.
      - `get_emails_by_gallery(table, gallery_id)`: Retrieve email schedules associated with a specific gallery.
      - `get_emails_by_order(table, order_id)`: Retrieve email schedules associated with a specific order.
      - `get_emails_by_job(table, job_id)`: Retrieve email schedules associated with a specific job.
      - `get_active_email_schedule_count(job_id)`: Get the count of active email schedules for a job.
      - `get_email_schedules_by_ids(ids, type)`: Retrieve email schedules by their IDs and category type.
      - `get_all_emails_schedules(organizations)`: Retrieve all email schedules for specified organizations.
      - `update_email_schedule(id, params)`: Update an email schedule with the given parameters.
      - `query_get_email_schedule(category_type, gallery_id, job_id, piepline_id, table \\ EmailSchedule)`: Query and retrieve
         email schedules based on category, gallery, and job.
      - `get_last_completed_email(category_type, gallery_id, job_id, pipeline_id, state)`: Get the last completed email schedule
         for a specific category, gallery, job, pipeline, and state.

  This module helps manage and retrieve email automation schedules for various organizational tasks.
  """
  import Ecto.Query
  alias Ecto.{Multi}

  alias Picsello.{
    Repo,
    Jobs,
    PaymentSchedules,
    EmailAutomations,
    EmailAutomation.EmailSchedule,
    EmailAutomation.EmailScheduleHistory,
    Galleries
  }

  def get_schedule_by_id_query(id) do
    from(es in EmailSchedule, where: es.id == ^id)
  end

  @doc """
  Retrieves an email automation schedule by its ID.

  This function queries the database to retrieve an email automation schedule based on its unique ID.
  It is commonly used to fetch specific email schedules for further processing or updates.

  ## Parameters

  - `id`: The unique identifier of the email automation schedule to retrieve.

  ## Returns

  Returns a single email automation schedule matching the provided ID or `nil` if no schedule is found.

  ## Example

  ```elixir
  # Retrieve an email automation schedule by its ID
  schedule = Picsello.EmailAutomationSchedules.get_schedule_by_id(123)

  # If found, the `schedule` variable will contain the email schedule details, otherwise, it will be `nil`.
  """

  def get_schedule_by_id(id) do
    get_schedule_by_id_query(id)
    |> Repo.one()
  end

  @doc """
  Get emails associated with a specific gallery.

  ## Parameters

      - `table`: The table to query for emails.
      - `gallery_id`: The gallery ID to filter by.

  ## Returns

  A list of emails associated with the specified gallery.
  """
  def get_emails_by_gallery(table, gallery_id, type) do
    from(es in table, where: es.gallery_id == ^gallery_id and es.type == ^type)
    |> Repo.all()
  end

  @doc """
  Get emails associated with a specific order.

  ## Parameters

      - `table`: The table to query for emails.
      - `order_id`: The order ID to filter by.

  ## Returns

  A list of emails associated with the specified order.
  """
  def get_emails_by_order(table, order_id, type) do
    from(es in table, where: es.order_id == ^order_id and es.type == ^type)
    |> Repo.all()
  end

  @doc """
  Get emails associated with a specific job.

  ## Parameters

      - `table`: The table to query for emails.
      - `job_id`: The job ID to filter by.

  ## Returns

  A list of emails associated with the specified job.
  """
  def get_emails_by_job(table, job_id, type) do
    from(es in table, where: es.job_id == ^job_id and es.type == ^type)
    |> Repo.all()
  end

  def get_emails_by_shoot(table, shoot_id, type) do
    from(es in table, where: es.shoot_id == ^shoot_id and es.type == ^type)
    |> Repo.all()
  end

  @doc """
  Get the count of active email schedules for a specific job.

  ## Parameters

      - `job_id`: The job ID to filter by.

  ## Returns

  The count of active email schedules for the specified job.
  """
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

  @doc """
  Get email schedules by IDs and type.

  ## Parameters

      - `ids`: A list of email schedule IDs.
      - `type`: The type of the schedule.

  ## Returns

  A structured representation of email schedules grouped by categories and subcategories.
  """
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

  ## Select specific fields and construct a structured representation of email schedule information.
  ## This function processes the query results to create a structured representation that includes
  ## category and subcategory information along with pipeline details and related email data.
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
            "to_jsonb(json_build_object('id', ?, 'name', ?, 'total_hours', ?, 'condition', ?, 'body_template', ?, 'subject_template', ?, 'private_name', ?, 'stopped_at', ?, 'reminded_at', ?, 'stopped_reason', ?, 'shoot_id', ?, 'order_id', ?, 'gallery_id', ?, 'job_id', ?))",
            email.id,
            email.name,
            email.total_hours,
            email.condition,
            email.body_template,
            email.private_name,
            email.private_name,
            email.stopped_at,
            email.reminded_at,
            email.stopped_reason,
            email.shoot_id,
            email.order_id,
            email.gallery_id,
            email.job_id
          )
        )
    })
  end

  @doc """
  Retrieve all email schedules associated with the specified organizations.

  This function queries the database to fetch all email schedules that belong to the provided organizations.
  It also preloads the associated email automation pipeline and categories for each schedule.

  ## Parameters

      - `organizations`: A list of organization IDs for which to retrieve email schedules.

  ## Returns

  A list of email schedules, each including preloaded data for email automation pipelines and categories.
  """
  def get_all_emails_schedules(organizations) do
    from(es in EmailSchedule, where: es.organization_id in ^organizations)
    |> preload(email_automation_pipeline: [:email_automation_category])
    |> Repo.all()
  end

  @doc """
  Updates the email schedule and creates a corresponding email schedule history entry.

  This function updates an email schedule with the provided `params` while creating a history entry.
  The `id` parameter specifies the ID of the email schedule to be updated.

  ## Parameters

      - `id`: An integer representing the ID of the email schedule to update.
      - `params`: A map containing the parameters for the update, including `reminded_at`.

  ## Returns

      - `{:ok, multi}` when the update and history entry creation are successful.
      - `{:error, multi}` when an error occurs during the update and history entry creation.

  ## Example

      ```elixir
      # Update an email schedule and create a corresponding history entry
      result = Picsello.EmailAutomations.update_email_schedule(123, %{
        reminded_at: DateTime.now()
      })

      # Check the result and handle accordingly
      case result do
        {:ok, _} -> IO.puts("Email schedule updated successfully.")
        {:error, _} -> IO.puts("Error updating email schedule.")
      end
  """
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

  ## Filter email schedules based on different criteria. This function filters email schedules
  ## based on specific criteria, such as galleries, orders, or jobs. It constructs a query that
  ## selects and groups email schedules according to the provided criteria, and returns the result.
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

  ## Filter email schedules based on job ID. This function filters email schedules based on a specific job ID.
  ## It constructs a query that selects and groups email schedules related to the provided job ID, and returns the result.
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

  ## Group email schedules by categories and subcategories. This function groups email schedules
  ## based on categories and subcategories. It processes the provided list of email schedules and
  ## organizes them into structured categories and subcategories.
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

  @doc """
  Queries the EmailSchedule or a specified table for email automation pipeline data based on the provided parameters.

  This function constructs a query to retrieve email schedule records from the specified table, filtered by the given
  `category_type`, `gallery_id`, `job_id`, and `pipeline_id`.

  ## Parameters

      - `category_type`: An atom representing the category type. Should be either `:gallery` or other values.
      - `gallery_id`: An integer representing the gallery ID for filtering.
      - `job_id`: An integer representing the job ID for filtering.
      - `pipeline_id`: An integer representing the email automation pipeline ID for filtering.
      - `table`: The table module where the query will be executed. Defaults to `EmailSchedule` if not provided.

  ## Returns

  A list of maps representing the email schedule records that match the specified criteria.

  ## Example

      ```elixir
      query_get_email_schedule(:gallery, 123, nil, 456, EmailSchedule)
  """
  def query_get_email_schedule(
        category_type,
        gallery_id,
        shoot_id,
        job_id,
        piepline_id,
        table \\ EmailSchedule
      ) do
    query = get_schedule_by_pipeline(table, piepline_id)

    case category_type do
      :gallery -> query |> where([es], es.gallery_id == ^gallery_id)
      :shoot -> query |> where([es], es.shoot_id == ^shoot_id)
      _ -> query |> where([es], es.job_id == ^job_id)
    end
  end

  def get_schedule_by_pipeline(table, pipeline_ids) when is_list(pipeline_ids) do
    from(es in table, where: es.email_automation_pipeline_id in ^pipeline_ids)
  end

  def get_schedule_by_pipeline(table, pipeline_id) do
    from(es in table, where: es.email_automation_pipeline_id == ^pipeline_id)
  end

  def get_all_emails_active_by_job_pipeline(category, job_id, pipeline_id) do
    query_get_email_schedule(category, nil, nil, job_id, pipeline_id)
    |> where([es], is_nil(es.stopped_at))
  end

  def stopped_all_active_proposal_emails(job_id) do
    pipeline = EmailAutomations.get_pipeline_by_state(:manual_booking_proposal_sent)

    all_proposal_active_emails_query =
      get_all_emails_active_by_job_pipeline(:lead, job_id, pipeline.id)

    delete_and_insert_schedules_by(
      all_proposal_active_emails_query,
      :proposal_accepted
    )
  end

  def delete_and_insert_schedules_by(email_schedule_query, stopped_reason) do
    schedule_history_params = make_schedule_history_params(email_schedule_query, stopped_reason)

    Multi.new()
    |> Multi.delete_all(:proposal_emails, email_schedule_query)
    |> Multi.insert_all(:schedule_history, EmailScheduleHistory, schedule_history_params)
    |> Repo.transaction()
  end

  def make_schedule_history_params(query, stopped_reason) do
    query
    |> Repo.all()
    |> Enum.map(fn schedule ->
      schedule
      |> Map.take([
        :total_hours,
        :condition,
        :type,
        :body_template,
        :name,
        :subject_template,
        :private_name,
        :reminded_at,
        :email_automation_pipeline_id,
        :job_id,
        :shoot_id,
        :gallery_id,
        :order_id,
        :organization_id
      ])
      |> Map.merge(%{
        stopped_reason: stopped_reason,
        stopped_at: DateTime.truncate(DateTime.utc_now(), :second),
        inserted_at: DateTime.truncate(DateTime.utc_now(), :second),
        updated_at: DateTime.truncate(DateTime.utc_now(), :second)
      })
    end)
  end

  def get_stopped_emails_text(job_id, state, helper) do
    pipeline = EmailAutomations.get_pipeline_by_state(state)

    emails_stopped =
      from(es in EmailScheduleHistory,
        where:
          es.email_automation_pipeline_id == ^pipeline.id and es.job_id == ^job_id and
            not is_nil(es.stopped_at)
      )
      |> Repo.all()

    if Enum.any?(emails_stopped) do
      count = Enum.count(emails_stopped)

      helper.ngettext("1 email stopped", "#{count} emails stopped", count)
    else
      nil
    end
  end

  @doc """
  Retrieves the last completed email from the specified pipeline for a given category type, gallery ID, shoot_id, job ID, pipeline id, state and helpers.

  This function first calls `query_get_email_schedule/6` to retrieve email schedule records, filters them to include only
  those with non-nil `reminded_at` values, and then sorts the emails based on the provided `state`. Finally, it returns
  the last email in the sorted list.

  ## Parameters

      - `category_type`: An atom representing the category type. Should be either `:gallery` or other values.
      - `gallery_id`: An integer representing the gallery ID for filtering.
      - `shoot_id`: An integer representing the shoot ID for filtering.
      - `job_id`: An integer representing the job ID for filtering.
      - `pipeline_id`: An integer representing the email automation pipeline ID for filtering.
      - `state`: A module responsible for sorting the email records.
      - `helpers`: A module responsible for calling the helper actions.

  ## Returns

  A map representing the last completed email record, or `nil` if no matching record is found.

  ## Example

      ```elixir
      get_last_completed_email(:gallery, 123, nil, 456, 4, active, MyEmailStateModule)
  """
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
    job = Jobs.get_job_by_id(job_id) |> Repo.preload([:job_status])

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

    cond do
      job.job_status.is_lead and Enum.empty?(previous_emails_schedules) and
          Enum.empty?(previous_emails_history) ->
        emails

      Enum.empty?(previous_emails_schedules) and Enum.empty?(previous_emails_history) and
          !PaymentSchedules.all_paid?(job) ->
        emails

      true ->
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
