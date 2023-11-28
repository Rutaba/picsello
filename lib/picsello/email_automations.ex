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
    EmailAutomation.EmailScheduleHistory,
    Notifiers.EmailAutomationNotifier,
    EmailPresets,
    Organization,
    PaymentSchedule,
    PaymentSchedules
  }

  alias Picsello.EmailAutomation.{
    GarbageEmailCollector,
    EmailAutomationPipeline,
    EmailAutomationSubCategory
  }

  alias Ecto.Multi

  @doc """
  Retrieves email presets for scheduling based on the provided organization, job type,
  email automation type, and optional skip sub-categories.

  This function queries the database for email presets that match the specified criteria.
  It filters email presets by the `organization_id`, `job_type`, and `type`. Additionally,
  you can provide an optional list of `skip_sub_categories` to exclude specific email automation
  sub-categories from the results.

  ## Parameters

      - `organization_id`: An integer representing the organization ID for filtering email presets.
      - `job_type`: An atom representing the type of job for filtering email presets.
      - `type`: A list of atoms specifying the email automation type to include.
      - `skip_sub_categories`: An optional list of strings representing sub-categories to exclude from the results. Defaults to an empty list.

  ## Returns

  A list of email presets that meet the specified criteria.

  ## Example

      ```elixir
      # Retrieve all active email presets for an organization with job type :example_job
      email_presets = Picsello.EmailAutomations.get_emails_for_schedule(123, :example_job, [:type1, :type2])

      # Retrieve email presets while excluding specific sub-categories
      email_presets = Picsello.EmailAutomations.get_emails_for_schedule(456, :another_job, [:type3], ["sub_category_A", "sub_category_B"])
  """
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

  @doc """
  Retrieves a list of email automation sub-categories.

  This function queries the database to fetch all email automation sub-categories and returns them as a list.

  ## Returns

  A list of email automation sub-categories.

  ## Example

      ```elixir
      # Retrieve all email automation sub-categories
      Picsello.EmailAutomations.get_sub_categories()
  """
  def get_sub_categories() do
    from(EmailAutomationSubCategory) |> Repo.all()
  end

  @doc """
  Retrieves an email automation pipeline by its ID.

  This function queries the database to find an email automation pipeline with the specified ID and returns it.

  ## Parameters

      - `id`: An integer representing the ID of the email automation pipeline to retrieve.

  ## Returns

  The email automation pipeline if found, or `nil` if no matching pipeline is found.

  ## Example

      ```elixir
      # Retrieve an email automation pipeline by its ID
      Picsello.EmailAutomations.get_pipeline_by_id(123)
  """
  def get_pipeline_by_id(id) do
    from(eap in EmailAutomationPipeline, where: eap.id == ^id)
    |> Repo.one()
  end

  def get_pipelines_by_states(states) do
    from(eap in EmailAutomationPipeline, where: eap.state in ^states)
    |> Repo.all()
  end

  @doc """
  Retrieves an email automation pipeline by its state.

  This function queries the database to find an email automation pipeline with the specified state and returns it.

  ## Parameters

      - `state`: An atom representing the state of the email automation pipeline to retrieve.

  ## Returns

  The email automation pipeline if found, or `nil` if no matching pipeline is found.

  ## Example

  ```elixir
      # Retrieve an email automation pipeline by its state
      Picsello.EmailAutomations.get_pipeline_by_state(:active)
  """
  def get_pipeline_by_state(state) do
    from(eap in EmailAutomationPipeline, where: eap.state == ^state)
    |> Repo.one()
  end

  @doc """
  Updates the status of email presets associated with a specific email automation pipeline.

  This function changes the status of email presets belonging to the specified `pipeline_id` based
  on the provided `active` parameter. It toggles the status between 'active' and 'disabled'.

  ## Parameters

      - `pipeline_id`: An integer representing the ID of the email automation pipeline.
      - `active`: A string representing the desired status, either "true" for 'active' or "false" for 'disabled'.

  ## Returns

  `{ROWS_COUNT_UPDATED, nil}` when the status update is successful, where ROWS_COUNT_UPDATED is any non_neg_integer.

  ## Example

      ```elixir
      # Set the status of email presets for a pipeline to 'active'
      Picsello.EmailAutomations.update_pipeline_and_settings_status(123, "true")
  """
  def update_pipeline_and_settings_status(pipeline_id, active) do
    status = toggle_status(active)

    from(es in EmailPreset,
      where: es.email_automation_pipeline_id == ^pipeline_id,
      update: [set: [status: ^status]]
    )
    |> Repo.update_all([])
  end

  @doc """
  Deletes an email preset by its ID.

  This function removes an email preset from the database based on the provided `email_preset_id`.

  ## Parameters

      - `email_preset_id`: An integer representing the ID of the email preset to delete.

  ## Returns

  `{:ok, EmailPreset.t()}` when the email preset is successfully deleted.

  ## Example

      ```elixir
      # Delete an email preset by its ID
      Picsello.EmailAutomations.delete_email(456)
  """
  def delete_email(email_preset_id) do
    from(p in EmailPreset,
      where: p.id == ^email_preset_id
    )
    |> Repo.one()
    |> Repo.delete()
  end

  @doc """
  Retrieves an email preset by its ID.

  This function queries the database to find an email preset with the specified `id` and returns it.

  ## Parameters

      - `id`: An integer representing the ID of the email preset to retrieve.

  ## Returns

  The email preset if found, or `nil` if no matching email preset is found.

  ## Example

      ```elixir
      # Retrieve an email preset by its ID
      Picsello.EmailAutomations.get_email_by_id(789)
  """
  def get_email_by_id(id) do
    from(
      ep in EmailPreset,
      where: ep.id == ^id
    )
    |> Repo.one()
  end

  @doc """
  Retrieves email data for all pipelines associated with a specific organization and job type.

  This function fetches data for all email automation pipelines that match the specified `organization_id`
  and `job_type`. It groups the pipelines by sub-category and includes email data for each pipeline.

  ## Parameters

      - `organization_id`: An integer representing the ID of the organization.
      - `job_type`: An atom representing the type of job.

  ## Returns

  A list of maps, each representing an automation configuration, including email data.

  ## Example

      ```elixir
      # Retrieve email data for all pipelines associated with an organization and job type
      Picsello.EmailAutomations.get_all_pipelines_emails(123, :example_job)
  """
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

  @doc """
  Retrieves a job by its ID and preloads associated data.

  This function fetches a job by its ID and preloads associated data, such as shoots, booking proposals,
  booking events, payment schedules, job status, client, and organization.

  ## Parameters

      - `id`: An integer representing the ID of the job to retrieve.

  ## Returns

  The job with preloaded associated data.

  ## Example

    ```elixir
    # Retrieve a job by its ID and preload associated data
    Picsello.EmailAutomations.get_job(456)

    Picsello.EmailAutomations.get_job(nil)
    nil
  """
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

  def update_globally_automations_emails(organization_id, "disabled") do
    email_schedules_query =
      EmailAutomationSchedules.get_all_emails_schedules_query([organization_id])

    Multi.new()
    |> Multi.update_all(:settings_update, update_automation_settings_query(organization_id),
      set: [status: "disabled"]
    )
    |> Multi.update(
      :organization_update,
      update_organization_global_automation_changeset(organization_id, false)
    )
    |> Multi.append(
      EmailAutomationSchedules.delete_and_insert_schedules_by_multi(
        email_schedules_query,
        :globally_stopped
      )
    )
    |> Repo.transaction()
  end

  def update_globally_automations_emails(organization_id, "enabled") do
    schedule_history_query =
      from(esh in EmailScheduleHistory,
        where: esh.organization_id == ^organization_id and esh.stopped_reason == :globally_stopped
      )

    Multi.new()
    |> Multi.update_all(:settings_update, update_automation_settings_query(organization_id),
      set: [status: "active"]
    )
    |> Multi.update(
      :organization_update,
      update_organization_global_automation_changeset(organization_id, true)
    )
    |> Multi.append(EmailAutomationSchedules.pull_back_email_schedules_multi(schedule_history_query))
    |> Repo.transaction()
  end

  def update_automation_settings_query(organization_id) do
    from(es in EmailPreset,
      where: es.organization_id == ^organization_id
    )
  end

  defp update_organization_global_automation_changeset(organization_id, enabled) do
    from(o in Organization, where: o.id == ^organization_id)
    |> Repo.one()
    |> Ecto.Changeset.change(global_automation_enabled: enabled)
  end

  @doc """
  Resolves variables in email content for a given EmailSchedule.

  This function takes an `EmailSchedule` struct as input and resolves variables in the email's body
  and subject templates using the provided schemas and helpers. The type of resolver module is determined
  based on the email automation category type, which can be either `:gallery` or other values.

  ## Parameters

      - `preset`: An `EmailSchedule` struct containing the email content to resolve.
      - `schemas`: A map of schemas relevant to the email content.
      - `helpers`: A map of helper functions for resolving variables.

  ## Returns

  A modified `EmailSchedule` struct with resolved body and subject templates.

  ## Example

      ```elixir
      # Create a resolved EmailSchedule struct
      Picsello.EmailAutomations.resolve_variables(email_schedule, schemas, helpers)
  """
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

  @doc """
  Resolves variables in a list of email subjects for a given context.

  This function takes a job, an optional gallery, a type, and a list of email subjects.
  It resolves variables in each subject using the provided context, which can be either a job or a gallery.
  If a gallery is provided, it is used as the context; otherwise, the job is used.

  ## Parameters

      - `job`: A map representing the job context.
      - `gallery`: A map representing the gallery context or `nil` if not applicable.
      - `type`: An atom specifying the context type, which can be `:gallery` or other values.
      - `subjects`: A list of email subjects to resolve.

  ## Returns

  A list of resolved email subjects.

  ## Example

      ```elixir
      # Resolve variables in a list of email subjects for a job context
      Picsello.EmailAutomations.resolve_all_subjects(job, nil, :job, subjects_list)

      # Resolve variables in a list of email subjects for a gallery context
      Picsello.EmailAutomations.resolve_all_subjects(job, gallery, :gallery, gallery_subjects_list)
  """
  def resolve_all_subjects(job, gallery, type, subjects) do
    schema = if is_nil(gallery), do: job, else: gallery

    Enum.map(subjects, fn subject ->
      resolve_variables_for_subject(schema, type, subject)
    end)
  end

  @doc """
  Sends an automated email for the 'gallery' context when specific states are matched.

  This function sends an automated email for the 'gallery' context, provided an email, gallery,
  and state match specific conditions. It is triggered when the state belongs to a predefined list of email types.

  ## Parameters

      - `type`: An atom, must be `:gallery` to specify the context.
      - `email`: A map representing the email to send.
      - `gallery`: A map representing the gallery.
      - `state`: An atom representing the state of the email.

  ## Returns

  `{:ok, Ecto.Multi.t()}` when the email is successfully sent.

  ## Example

  ```elixir
  # Send an automated email for the 'gallery' context
  Picsello.EmailAutomations.send_now_email(:gallery, email_map, gallery_map, :manual_gallery_send_link)
  """
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

    EmailAutomationNotifier.deliver_automation_email_gallery(
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

    EmailAutomationNotifier.deliver_automation_email_order(
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

    EmailAutomationNotifier.deliver_automation_email_job(
      email,
      job,
      {job, payment_schedule},
      state,
      PicselloWeb.Helpers
    )
    |> update_schedule(email.id)
  end

  ## Retrieves information about all email automation pipelines and their categories. This function retrieves
  ## information about all email automation pipelines, their associated email automation categories, and subcategories.
  ## It provides a structured representation of the pipelines along with their metadata.
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

  ## Groups email automation pipelines by category and subcategory. This function takes a list of email
  ## automation pipelines and organizes them into a hierarchical structure grouped by category and subcategory.
  ## It provides a structured representation of the pipelines, subcategories, and categories.
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

  ## Updates an email schedule with a `reminded_at` timestamp. This function updates an email schedule
  ## with a `reminded_at` timestamp if the result is `{:ok, _}`. If the result is an error, it returns the error itself.
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

  @doc """
  Removes extraneous data from a list of subcategories.

  This function takes a list of subcategories, each represented as a map, and removes extraneous data,
  retaining only specific keys such as `pipelines`, `subcategory_id`, `subcategory_slug`, and `subcategory_name`.

  ## Parameters

      - `sub_categories`: A list of maps representing subcategories with additional data.

  ## Returns

  A list of maps with the specified keys, removing other data.

  ## Example

      ```elixir
      # Remove extraneous data from a list of subcategories
      Picsello.EmailAutomations.remove_categories_from_list(sub_categories_list)
  """
  def remove_categories_from_list(sub_categories) do
    Enum.map(sub_categories, fn sub_category ->
      sub_category
      |> Map.take([:pipelines, :subcategory_id, :subcategory_slug, :subcategory_name])
    end)
  end

  ## Toggles the status value. These functions takes a `status` value as a string
  ## and toggles it based on the following rules:
  ##    - If the `status` is "true", it returns "disabled".
  ##    - If the `status` is "false", it returns "active".
  defp toggle_status("true"), do: "disabled"
  defp toggle_status("false"), do: "active"

  ## Resolves variables in the email subject. This function resolves variables in the provided email
  ## subject based on the given schema and context type. It uses the appropriate resolver module to
  ## process the subject and replace variables with their values.
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

  ## Retrieves email presets for a specific pipeline, organization, and job type. This function retrieves
  ## email presets that match the specified `pipeline_id`, `organization_id`, and `job_type`. It returns a
  ## list of email presets associated with the given criteria.
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

  ## Determine the schemas for email automation based on the provided gallery. This function determines
  ## the schemas for email automation based on the provided gallery. It returns either a single gallery
  ## schema or a tuple of gallery and album schemas, depending on the type of the gallery.
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
    state_full_paid = if state == :pays_retainer_offline, do: :paid_offline_full, else: :paid_full

    if PaymentSchedules.all_paid?(job) do
      send_email_by_state(job, state_full_paid, organization_id)
      GarbageEmailCollector.stop_job_and_lead_emails(job)
    else
      send_email_by_state(job, state, organization_id)
    end
  end

  def send_email_by_state(job, state, organization_id) do
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
        :lead,
        job.type,
        pipeline.id,
        organization_id
      )
      |> List.first()
      |> preload_email()

    send_automation_email(email_schedule, email_preset, job, state)
  end

  defp send_automation_email(nil, nil, _job, _state), do: nil

  defp send_automation_email(nil, email_preset, job, state) do
    EmailAutomationNotifier.deliver_automation_email_job(
      email_preset,
      job,
      {job},
      state,
      PicselloWeb.Helpers
    )
  end

  defp send_automation_email(email_schedule, _email_preset, job, state) do
    EmailAutomationNotifier.deliver_automation_email_job(
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

  def broadcast_count_of_emails(job_id) do
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "emails_count:#{job_id}",
      {:update_emails_count, %{job_id: job_id}}
    )
  end
end
