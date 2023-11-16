defmodule Picsello.BookingEvents do
  @moduledoc "context module for booking events"
  alias Picsello.{
    Repo,
    BookingEvent,
    Job,
    Package,
    BookingEventDate,
    BookingEventDates,
    EmailAutomations,
    EmailAutomationSchedules
  }

  alias Ecto.{Multi, Changeset}
  alias Picsello.Workers.ExpireBooking
  import Ecto.Query

  defmodule Booking do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:name, :string)
      field(:email, :string)
      field(:phone, :string)
      field(:date, :date)
      field(:time, :time)
    end

    def changeset(attrs \\ %{}) do
      %__MODULE__{}
      |> cast(attrs, [:name, :email, :phone, :date, :time])
      |> validate_required([:name, :email, :phone, :date, :time])
    end
  end

  def create_booking_event(params) do
    %BookingEvent{}
    |> BookingEvent.create_changeset(params)
    |> Repo.insert()
  end

  def duplicate_booking_event(booking_event_id, organization_id) do
    booking_event_params =
      get_booking_event!(
        organization_id,
        booking_event_id
      )
      |> Repo.preload([:dates])
      |> Map.put(:status, :active)
      |> Map.from_struct()

    to_duplicate_booking_event =
      if String.contains?(booking_event_params.name, "duplicate-") do
        number =
          Regex.run(~r/-([0-9]+)/, booking_event_params.name)
          |> Enum.at(1)
          |> String.to_integer()

        new_number = number + 1

        name =
          String.replace(
            booking_event_params.name,
            "duplicate-#{number}",
            "duplicate-" <> "#{new_number}"
          )

        booking_event_params
        |> Map.merge(%{name: name})
      else
        booking_event_params
        |> Map.merge(%{name: booking_event_params.name <> " " <> "duplicate-1"})
      end

    to_duplicate_event_dates =
      to_duplicate_booking_event.dates
      |> Enum.map(fn t ->
        t
        |> Map.replace(:date, nil)
        |> Map.replace(:slots, BookingEventDates.transform_slots(t.slots))
      end)

    multi =
      Multi.new()
      |> Multi.insert(
        :duplicate_booking_event,
        BookingEvent.duplicate_changeset(to_duplicate_booking_event)
      )

    to_duplicate_event_dates
    |> Enum.with_index()
    |> Enum.reduce(multi, fn {event_date, i}, multi ->
      multi
      |> Multi.insert(
        "duplicate_booking_event_date_#{i}",
        fn %{duplicate_booking_event: event} ->
          BookingEventDate.duplicate_changeset(%{
            booking_event_id: event.id,
            location: event_date.location,
            address: event_date.address,
            session_length: event_date.session_length,
            session_gap: event_date.session_gap,
            time_blocks: to_map(event_date.time_blocks),
            slots: to_map(event_date.slots)
          })
        end
      )
    end)
    |> Repo.transaction()
  end

  def upsert_booking_event(changeset) do
    changeset |> Repo.insert_or_update()
  end

  def get_all_booking_events(organization_id) do
    from(event in BookingEvent, where: event.organization_id == ^organization_id)
    |> Repo.all()
  end

  def sorted_booking_event(booking_event) do
    booking_event =
      booking_event
      |> Picsello.Repo.preload([
        :dates,
        package_template: [:package_payment_schedules, :contract, :questionnaire_template]
      ])

    dates = reorder_time_blocks(booking_event.dates) |> Enum.sort_by(& &1.date, {:desc, Date})
    Map.put(booking_event, :dates, dates)
  end

  def get_booking_events_public(organization_id) do
    from(event in BookingEvent,
      join: package in assoc(event, :package_template),
      left_join: booking_date in assoc(event, :dates),
      where: package.organization_id == ^organization_id,
      where: event.status == :active,
      select: %{
        package_name: package.name,
        id: event.id,
        name: event.name,
        thumbnail_url: event.thumbnail_url,
        status: event.status,
        location: event.location,
        duration_minutes: event.duration_minutes,
        package_template: package,
        dates:
          fragment(
            "array_agg(to_jsonb(json_build_object('id', ?, 'booking_event_id', ?, 'date', ?)))",
            booking_date.id,
            booking_date.booking_event_id,
            booking_date.date
          ),
        description: event.description,
        address: event.address
      },
      group_by: [event.id, package.id, booking_date.booking_event_id]
    )
    |> Repo.all()
  end

  def get_booking_events(organization_id,
        filters: %{sort_by: sort_by, sort_direction: sort_direction} = opts
      ) do
    from(event in BookingEvent,
      left_join: job in assoc(event, :jobs),
      left_join: status in assoc(job, :job_status),
      left_join: package in assoc(event, :package_template),
      left_join: booking_date in assoc(event, :dates),
      where: event.organization_id == ^organization_id,
      where: ^filters_search(opts),
      where: ^filters_status(opts),
      select: %{
        booking_count: fragment("sum(case when ?.is_lead = false then 1 else 0 end)", status),
        can_edit?: fragment("count(?.*) = 0", job),
        package_template_id: event.package_template_id,
        package_name: package.name,
        id: event.id,
        name: event.name,
        thumbnail_url: event.thumbnail_url,
        status: event.status,
        dates:
          fragment(
            "array_agg(to_jsonb(json_build_object('id', ?, 'booking_event_id', ?, 'date', ?)))",
            booking_date.id,
            booking_date.booking_event_id,
            booking_date.date
          ),
        duration_minutes: event.duration_minutes,
        inserted_at: event.inserted_at
      },
      group_by: [event.id, package.name, booking_date.booking_event_id],
      order_by: ^filter_order_by(sort_by, sort_direction)
    )
    |> Repo.all()
  end

  defp filters_search(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {:search_phrase, nil}, dynamic ->
        dynamic

      {:search_phrase, search_phrase}, dynamic ->
        search_phrase = "%#{search_phrase}%"

        dynamic(
          [client, jobs, job_status, package],
          ^dynamic and
            (ilike(client.name, ^search_phrase) or
               ilike(package.name, ^search_phrase))
        )

      {_, _}, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  defp filters_status(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {:status, value}, dynamic ->
        case value do
          "disabled_events" ->
            filter_disabled_events(dynamic)

          "archived_events" ->
            filter_archived_events(dynamic)

          _ ->
            remove_archive_events(dynamic)
        end

      _any, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  defp remove_archive_events(dynamic) do
    dynamic(
      [client, jobs, job_status],
      ^dynamic and client.status != :archive
    )
  end

  defp filter_disabled_events(dynamic) do
    dynamic(
      [client, jobs, job_status],
      ^dynamic and client.status == :disabled
    )
  end

  defp filter_archived_events(dynamic) do
    dynamic(
      [client, jobs, job_status],
      ^dynamic and client.status == :archive
    )
  end

  # returned dynamic with join binding
  defp filter_order_by(:id, order),
    do: [{order, dynamic([client, event], count(field(event, :id)))}]

  defp filter_order_by(column, order) do
    column = update_column(column)
    [{order, dynamic([client], field(client, ^column))}]
  end

  def update_column(:date), do: :dates
  def update_column(column), do: column

  def get_booking_event!(organization_id, event_id) do
    from(event in BookingEvent, where: event.organization_id == ^organization_id)
    |> Repo.get!(event_id)
  end

  def get_preloaded_booking_event!(organization_id, event_id) do
    from(event in BookingEvent,
      join: package in assoc(event, :package_template),
      where: package.organization_id == ^organization_id,
      preload: [
        :dates,
        package_template: [:package_payment_schedules, :contract, :questionnaire_template]
      ]
    )
    |> Repo.get!(event_id)
  end

  # TODO: delete this function, old implementation
  def available_times(%BookingEvent{} = booking_event, date, opts \\ []) do
    duration = (booking_event.duration_minutes || Picsello.Shoot.durations() |> hd) * 60

    duration_buffer =
      ((booking_event.duration_minutes || Picsello.Shoot.durations() |> hd) +
         (booking_event.buffer_minutes || 0)) * 60

    skip_overlapping_shoots = opts |> Keyword.get(:skip_overlapping_shoots, false)

    case booking_event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        Enum.map(time_blocks, fn %{start_time: start_time, end_time: end_time} ->
          get_available_slots_each_block(start_time, end_time, duration, duration_buffer)
        end)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.filter(&(!is_nil(&1)))
        |> filter_overlapping_shoots(booking_event, date, skip_overlapping_shoots)
        |> filter_is_break_slots(booking_event, date)

      _ ->
        []
    end
  end

  # TODO: delete this function, old implementation
  defp get_available_slots_each_block(start_time, end_time, duration, duration_buffer) do
    if !is_nil(start_time) and !is_nil(end_time) do
      available_slots = (Time.diff(end_time, start_time) / duration) |> trunc()
      slot = 0..(available_slots - 1)

      get_available_slots_each_block(
        slot,
        available_slots,
        duration,
        duration_buffer,
        start_time,
        end_time
      )
    end
  end

  # TODO: delete this function, old implementation
  defp get_available_slots_each_block(
         slot,
         available_slots,
         duration,
         duration_buffer,
         start_time,
         end_time
       ) do
    if available_slots > 0 do
      Enum.reduce_while(slot, [], fn x, acc ->
        %{slot_start: slot_time, slot_end: slot_end} =
          if x != available_slots do
            %{
              slot_start: start_time |> Time.add(duration_buffer * x),
              slot_end: start_time |> Time.add(duration_buffer * (x + 1))
            }
          else
            %{
              slot_start: start_time |> Time.add(duration * x),
              slot_end: start_time |> Time.add(duration * (x + 1))
            }
          end

        slot_trunc = slot_end |> Time.truncate(:second)
        time = duration * -1
        end_trunc = end_time |> Time.add(time) |> Time.truncate(:second)

        if slot_trunc > end_trunc do
          {:halt, [slot_time | acc]}
        else
          {:cont, [slot_time | acc]}
        end
      end)
      |> Enum.reverse()
    else
      []
    end
  end

  # TODO: delete this function, old implementation
  def assign_booked_block_dates(dates, %BookingEvent{} = booking_event) do
    dates
    |> Enum.map(fn %{date: date, time_blocks: time_blocks} = block ->
      blocks =
        available_times(booking_event, date)
        |> fetch_blocks(time_blocks)

      block |> Map.put(:time_blocks, blocks)
    end)
  end

  # TODO: delete this function, old implementation
  defp fetch_blocks(all_slots, time_blocks) do
    Enum.map(time_blocks, fn block ->
      is_booked_block = is_blocked_booked(block, all_slots)

      block =
        case block.is_break and is_booked_block do
          true -> Map.put(block, :is_valid, false)
          _ -> Map.put(block, :is_valid, true)
        end

      block |> Map.put(:is_booked, is_booked_block)
    end)
  end

  # TODO: delete this function, old implementation
  def is_blocked_booked(
        %{start_time: start_time, end_time: end_time},
        _slots
      )
      when is_nil(start_time) or is_nil(end_time),
      do: false

  # TODO: delete this function, old implementation
  def is_blocked_booked(
        %{start_time: %Time{} = start_time, end_time: %Time{} = end_time},
        slots
      ) do
    Enum.count(slots, fn {slot_time, is_available, _is_break, _is_hide} ->
      !is_available && Time.compare(slot_time, start_time) in [:gt, :eq] &&
        Time.compare(slot_time, end_time) in [:lt]
    end) > 0
  end

  # TODO: delete this function, old implementation
  defp filter_is_break_slots(slot_times, booking_event, date) do
    slot_times
    |> Enum.map(fn {slot_time, is_available, _is_break, _is_hide} ->
      blocker_slots = filter_is_break_time_slots(booking_event, slot_time, date)
      hidden_slots = filter_is_hidden_time_slots(booking_event, slot_time, date)
      is_break = Enum.any?(blocker_slots)
      is_hidden = Enum.any?(hidden_slots)
      {slot_time, is_available, is_break, is_hidden}
    end)
  end

  # TODO: delete this function, old implementation
  defp filter_is_break_time_slots(booking_event, slot_time, date) do
    case booking_event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        for(
          %{
            start_time: %Time{} = start_time,
            end_time: %Time{} = end_time,
            is_break: is_break
          } <- time_blocks
        ) do
          if is_break do
            Time.compare(slot_time, start_time) in [:gt, :eq] &&
              Time.compare(slot_time, end_time) in [:lt]
          end
        end

      _ ->
        false
    end
  end

  # TODO: delete this function, old implementation
  defp filter_is_hidden_time_slots(booking_event, slot_time, date) do
    case booking_event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        for(
          %{
            start_time: %Time{} = start_time,
            end_time: %Time{} = end_time,
            is_hidden: is_hidden
          } <- time_blocks
        ) do
          if is_hidden do
            Time.compare(slot_time, start_time) in [:gt, :eq] &&
              Time.compare(slot_time, end_time) in [:lt]
          end
        end

      _ ->
        false
    end
  end

  # TODO: delete this function, old implementation
  defp filter_overlapping_shoots(slot_times, _booking_event, _date, true) do
    slot_times |> Enum.map(fn slot_time -> {slot_time, true, true, true} end)
  end

  # TODO: delete this function, old implementation
  defp filter_overlapping_shoots(
         slot_times,
         %BookingEvent{} = booking_event,
         date,
         false
       ) do
    %{package_template: %{organization: %{user: user} = organization}} =
      booking_event
      |> Repo.preload(package_template: [organization: :user])

    beginning_of_day = DateTime.new!(date, ~T[00:00:00], user.time_zone)

    end_of_day_with_buffer =
      DateTime.new!(date, ~T[23:59:59], user.time_zone)
      |> DateTime.add((Picsello.Shoot.durations() |> Enum.max()) * 60)

    shoots =
      from(shoot in Picsello.Shoot,
        join: job in assoc(shoot, :job),
        join: client in assoc(job, :client),
        where:
          client.organization_id == ^organization.id and is_nil(job.archived_at) and
            is_nil(job.completed_at),
        where: shoot.starts_at >= ^beginning_of_day and shoot.starts_at <= ^end_of_day_with_buffer
      )
      |> Repo.all()

    slot_times
    |> Enum.map(fn slot_time ->
      slot_start = DateTime.new!(date, slot_time, user.time_zone)

      slot_end =
        slot_start
        |> DateTime.add(booking_event.duration_minutes * 60)
        |> DateTime.add((booking_event.buffer_minutes || 0) * 60 - 1)

      is_available =
        !Enum.any?(shoots, fn shoot ->
          start_time = shoot.starts_at |> DateTime.shift_zone!(user.time_zone)
          end_time = shoot.starts_at |> DateTime.add(shoot.duration_minutes * 60)
          is_slot_booked(booking_event.buffer_minutes, slot_start, slot_end, start_time, end_time)
        end)

      {slot_time, is_available, false, false}
    end)
  end

  # TODO: delete this function, old implementation
  defp is_slot_booked(nil, slot_start, slot_end, start_time, end_time) do
    (DateTime.compare(slot_start, start_time) in [:gt, :eq] &&
       DateTime.compare(slot_start, end_time) == :lt) ||
      (DateTime.compare(slot_end, start_time) in [:gt, :eq] &&
         DateTime.compare(slot_end, end_time) == :lt)
  end

  # TODO: delete this function, old implementation
  defp is_slot_booked(_buffer, slot_start, slot_end, start_time, end_time) do
    (DateTime.compare(slot_start, start_time) in [:gt, :eq] &&
       DateTime.compare(slot_start, end_time) in [:lt, :eq]) ||
      (DateTime.compare(slot_end, start_time) in [:gt, :eq] &&
         DateTime.compare(slot_end, end_time) in [:lt, :eq])
  end

  @doc """
    saves a booking for a slot by creating its job, shoots, proposal, contract and updating the slot.
  """
  def save_booking(
        booking_event,
        booking_date,
        %{
          email: email,
          name: name,
          phone: phone,
          date: date,
          time: time
        },
        %{slot_index: slot_index, slot_status: slot_status}
      ) do
    %{package_template: %{organization: %{user: photographer}} = package_template} =
      booking_event
      |> Repo.preload(package_template: [organization: :user])

    starts_at = shoot_start_at(date, time, photographer.time_zone)

    Multi.new()
    |> Picsello.Jobs.maybe_upsert_client(
      %Picsello.Client{email: email, name: name, phone: phone},
      photographer
    )
    |> Multi.insert(:job, fn %{client: client} ->
      Picsello.Job.create_changeset(%{
        type: package_template.job_type,
        client_id: client.id,
        is_reserved?: slot_status == :reserved
      })
      |> Changeset.put_change(:booking_event_id, booking_event.id)
    end)
    |> Multi.update(:booking_date_slot, fn %{client: client, job: job} ->
      BookingEventDate.update_slot_changeset(booking_date, slot_index, %{
        job_id: job.id,
        client_id: client.id,
        status: slot_status
      })
    end)
    |> Multi.merge(fn %{job: job} ->
      package_payment_schedules =
        package_template
        |> Repo.preload(:package_payment_schedules, force: true)
        |> Map.get(:package_payment_schedules)

      shoot_date = starts_at |> DateTime.shift_zone!("Etc/UTC")

      payment_schedules =
        package_payment_schedules
        |> Enum.map(fn schedule ->
          schedule
          |> Map.from_struct()
          |> Map.drop([:package_payment_preset_id])
          |> Map.put(:shoot_date, shoot_date)
          |> Map.put(:schedule_date, get_schedule_date(schedule, shoot_date))
        end)

      opts =
        if booking_event.include_questionnaire?,
          do: %{
            payment_schedules: payment_schedules,
            action: :insert,
            total_price: Package.price(package_template),
            questionnaire: Picsello.Questionnaire.for_package(package_template)
          },
          else: %{
            payment_schedules: payment_schedules,
            action: :insert,
            total_price: Package.price(package_template)
          }

      package_template
      |> Map.put(:is_template, false)
      |> Picsello.Packages.changeset_from_template()
      |> Picsello.Packages.insert_package_and_update_job(job, opts)
    end)
    |> Multi.merge(fn %{package: package} ->
      Picsello.Contracts.maybe_add_default_contract_to_package_multi(package)
    end)
    |> Multi.insert(:shoot, fn %{job: job} ->
      Picsello.Shoot.create_booking_event_shoot_changeset(
        booking_event
        |> Map.take([:name, :location, :address])
        |> Map.put(:starts_at, starts_at)
        |> Map.put(:job_id, job.id)
        |> Map.put(:duration_minutes, booking_date.session_length)
      )
    end)
    |> Ecto.Multi.insert(:proposal, fn %{job: job, package: package} ->
      questionnaire_id =
        if booking_event.include_questionnaire?,
          do: package.questionnaire_template_id,
          else: nil

      Picsello.BookingProposal.create_changeset(%{
        job_id: job.id,
        questionnaire_id: questionnaire_id
      })
    end)
    |> then(fn
      multi when slot_status == :booked ->
        Oban.insert(multi, :oban_job, fn %{job: job} ->
          # multiply booking reservation by 2 to account for time spent on Stripe checkout
          expiration = Application.get_env(:picsello, :booking_reservation_seconds) * 2

          ExpireBooking.new(
            %{id: job.id, booking_date_id: booking_date.id, slot_index: slot_index},
            schedule_in: expiration
          )
        end)

      multi ->
        multi
    end)
    |> Repo.transaction()
  end

  @doc "expires a booking on a specific slot by expiring its job and updating the slot status to :open"
  def expire_booking(%{
        "id" => job_id,
        "booking_date_id" => booking_date_id,
        "slot_index" => slot_index
      }) do
    {:ok, _} =
      Job
      |> Repo.get(job_id)
      |> expire_booking_job()

    {:ok, _} =
      BookingEventDates.update_slot_status(booking_date_id, slot_index, %{
        job_id: nil,
        client_id: nil,
        status: :open
      })
  end

  defp get_schedule_date(schedule, shoot_date) do
    case schedule.interval do
      true ->
        transform_text_to_date(schedule.due_interval, shoot_date)

      _ ->
        transform_text_to_date(schedule, shoot_date)
    end
  end

  defp transform_text_to_date(%{} = schedule, shoot_date) do
    due_at = schedule.due_at

    if due_at || schedule.shoot_date do
      if due_at, do: due_at |> Timex.to_datetime(), else: shoot_date
    else
      last_shoot_date = shoot_date
      count_interval = schedule.count_interval
      count_interval = if count_interval, do: count_interval |> String.to_integer(), else: 1
      time_interval = schedule.time_interval

      time_interval =
        if(time_interval, do: time_interval <> "s", else: "Days")
        |> String.downcase()
        |> String.to_atom()

      if(schedule.shoot_interval == "Before 1st Shoot",
        do: Timex.shift(shoot_date, [{time_interval, -count_interval}]),
        else: Timex.shift(last_shoot_date, [{time_interval, -count_interval}])
      )
    end
  end

  defp transform_text_to_date("" <> due_interval, shoot_date) do
    cond do
      String.contains?(due_interval, "6 Months Before") ->
        Timex.shift(shoot_date, months: -6)

      String.contains?(due_interval, "1 Month Before") ->
        Timex.shift(shoot_date, months: -1)

      String.contains?(due_interval, "Week Before") ->
        Timex.shift(shoot_date, days: -7)

      String.contains?(due_interval, "Day Before") ->
        Timex.shift(shoot_date, days: -1)

      String.contains?(due_interval, "To Book") ->
        DateTime.utc_now() |> DateTime.truncate(:second)

      true ->
        shoot_date
    end
  end

  def disable_booking_event(event_id, organization_id) do
    get_booking_event!(organization_id, event_id)
    |> BookingEvent.disable_changeset()
    |> Repo.update()
  end

  def archive_booking_event(event_id, organization_id) do
    get_booking_event!(organization_id, event_id)
    |> BookingEvent.archive_changeset()
    |> Repo.update()
  end

  def enable_booking_event(event_id, organization_id) do
    get_booking_event!(organization_id, event_id)
    |> BookingEvent.enable_changeset()
    |> Repo.update()
  end

  @doc "expires a job created for a booking"
  def expire_booking_job(%Job{} = job) do
    with %Job{
           job_status: job_status,
           client: %{organization: organization},
           payment_schedules: payment_schedules
         } <-
           job |> Repo.preload([:payment_schedules, :job_status, client: :organization]),
         %Picsello.JobStatus{is_lead: true} <- job_status,
         {:ok, _} <-
           EmailAutomationSchedules.insert_job_emails(
             job.type,
             organization.id,
             job.id,
             :lead,
             [
               :client_contact
             ]
           ),
         _email_sent <-
           EmailAutomations.send_email_by_state(job, :abandoned_emails, organization.id),
         {:ok, _} <- Picsello.Jobs.archive_job(job) do
      for %{stripe_session_id: "" <> session_id} <- payment_schedules,
          do:
            {:ok, _} =
              Picsello.Payments.expire_session(session_id,
                connect_account: organization.stripe_account_id
              )

      {:ok, job}
    else
      %Picsello.JobStatus{is_lead: false} -> {:ok, job}
      {:error, error} -> {:error, error}
    end
  end

  def preload_booking_event(event),
    do:
      Repo.preload(event,
        dates:
          from(d in BookingEventDate,
            where: d.booking_event_id == ^event.id,
            order_by: d.date,
            preload: [slots: [:client, :job]]
          ),
        package_template: [:package_payment_schedules, :contract, :questionnaire_template]
      )

  @doc """
  This function, overlap_time?, takes a list of time blocks represented as maps and determines if there is any overlap between consecutive time blocks based on their end and start times.

  ## Parameters:

    - blocks (type: [map]): A list of maps representing time blocks. Each map should have at least two fields, end_time and start_time, which are expected to be of type %Time{}. These fields represent the end time of the previous block and the start time of the current block, respectively.

  ## Returns:

    - boolean: Returns true if there is any overlap between consecutive time blocks, otherwise false.

  ## Example:

  ```elixir
      blocks = [
      %{end_time: %Time{hour: 10, minute: 30}, start_time: %Time{hour: 9, minute: 0}},
      %{end_time: %Time{hour: 12, minute: 0}, start_time: %Time{hour: 11, minute: 0}},
      %{end_time: %Time{hour: 14, minute: 0}, start_time: %Time{hour: 13, minute: 30}}
    ]

    overlap = overlap_time?(blocks)  # Should return true, as there is an overlap between the second and third blocks.

    blocks_without_overlap = [
      %{end_time: %Time{hour: 10, minute: 30}, start_time: %Time{hour: 9, minute: 0}},
      %{end_time: %Time{hour: 11, minute: 0}, start_time: %Time{hour: 10, minute: 30}},
      %{end_time: %Time{hour: 13, minute: 30}, start_time: %Time{hour: 11, minute: 0}}
    ]

    overlap_time?(blocks_without_overlap)  # Should return false, as there is no overlap between any of the blocks.
  ```

  ## Note:

    - The function checks for overlap between consecutive time blocks by comparing the end time of one block with the start time of the next block. If the end time of a block is greater than the start time of the next block, it considers them to be overlapping.
    - The function uses the Time.compare/2 function to perform the time comparison. Ensure that the %Time{} structs in your input data are correctly formatted.
  """
  @spec overlap_time?(blocks :: [map]) :: boolean
  def overlap_time?(blocks) do
    for(
      [%{end_time: %Time{} = previous_time}, %{start_time: %Time{} = start_time}] <-
        Enum.chunk_every(blocks, 2, 1),
      do: Time.compare(previous_time, start_time) == :gt
    )
    |> Enum.any?()
  end

  @doc """
  Calculates a list of recurring dates based on a given booking event date and selected days.

  This function takes a booking event date and a list of selected days and calculates a
  list of recurring dates based on the provided parameters. The recurring dates are
  determined by the `occurences`, `calendar`, `repeat_interval`, and `selected_days` parameters.
  The calculation continues until the specified number of occurrences is reached or until the date
  exceeds the `stop_repeating` date, whichever comes first.

  ## Parameters

  - `booking_event_date` (map): A map containing the booking event date and other relevant parameters.
    - `:date` (date): The initial booking event date.
    - `:stop_repeating` (date): The date at which the recurrence should stop.
    - `:occurences` (integer): The maximum number of occurrences (or 0 for unlimited).
    - `:calendar` (string): The calendar type (e.g., "week", "month" or "year").
    - `:count_calendar` (integer): The calendar count.

  - `selected_days` (list of integers): A list of selected days of the week
  (1-7, where 1 is Sunday, 2 is Monday, etc.) on which the event should recur.

  ## Returns

  - A list of recurring dates.

  ## Examples

  booking_event_date = %{
    date: ~D[2023-09-01],
    stop_repeating: ~D[2023-09-30],
    occurences: 0,
    calendar: "week",
    count_calendar: 1
  }
  selected_days = [2, 4] # Recur on Tuesdays and Thursdays

  # Returns a list of recurring dates.
  calculate_dates(booking_event_date, selected_days)
  """
  @spec calculate_dates(map(), [map()]) :: [Datetime.t()]
  def calculate_dates(booking_event_date, selected_days) do
    selected_days = selected_days_indexed_array(selected_days)

    calculate_dates(
      Map.get(booking_event_date, :date),
      Map.get(booking_event_date, :stop_repeating),
      Map.get(booking_event_date, :occurences),
      Map.get(booking_event_date, :calendar),
      Map.get(booking_event_date, :count_calendar),
      selected_days,
      []
    )
  end

  @doc """
  Converts a list of structs to a list of maps.

  This function takes a list of structs and converts each struct into a map using the `Map.from_struct/1` function.
  It returns a new list containing the converted maps. This can be useful when you need to work with data in map
  format, such as when interacting with certain Elixir functions or libraries that expect map data.

  ## Parameters

  - `data` ([struct()]): A list of structs to be converted into maps.

  ## Returns

  A list of maps, where each map corresponds to a struct in the original list.

  ## Example

  ```elixir
  # Convert a list of structs to a list of maps
  iex> data = [%MyStruct{id: 1, name: "Alice"}, %MyStruct{id: 2, name: "Bob"}]
  iex> to_map(data)
  [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}]

  ## Notes

  This function simplifies the process of converting structs to maps for various Elixir operations that work with maps.
  """
  @spec to_map(data :: [struct()]) :: [map()]
  def to_map(data), do: Enum.map(data, &Map.from_struct(&1))

  # Compares two dates to check if date is less than stopped_date. some base-cases are added as well
  # to have a check on some inputs for the function i.e. if date and stopped-date are nil, then return false
  # instead of calling the difference functions which would make function fall apart.
  defp date_valid?(%Date{} = date, %Date{} = stopped_date),
    do: Date.compare(date, stopped_date) == :lt

  defp date_valid?(_date, _stopped_date), do: false

  # Recursively calculates a list of dates based on specified criteria.
  defp calculate_dates(
         booking_date,
         stopped_date,
         occurences,
         calendar,
         repeat_interval,
         selected_days,
         acc_dates
       ) do
    recursive_cond? =
      if occurences > 0,
        do: Enum.count(acc_dates) <= occurences,
        else: date_valid?(booking_date, stopped_date)

    if recursive_cond? do
      shifted_date = calendar_shift(calendar, repeat_interval, booking_date)

      dates =
        calculate_week_day_date(
          acc_dates,
          shifted_date,
          occurences,
          stopped_date,
          selected_days
        )

      calculate_dates(
        shifted_date,
        stopped_date,
        occurences,
        calendar,
        repeat_interval,
        selected_days,
        dates
      )
    else
      Enum.reverse(acc_dates) |> Enum.sort()
    end
  end

  # Calculates dates based on specified weekdays, within certain criteria.
  defp calculate_week_day_date(dates, shifted_date, occurences, stopped_date, selected_days) do
    shifted_date = Timex.shift(shifted_date, days: -1)

    Enum.reduce_while(1..7, dates, fn n, acc ->
      next_day = Timex.shift(shifted_date, days: n)
      weekday = day_of_week(next_day)

      halt_condition =
        if occurences > 0,
          do: Enum.count(acc) > occurences,
          else: !date_valid?(next_day, stopped_date)

      cond do
        halt_condition -> {:halt, acc}
        weekday in selected_days -> {:cont, acc ++ [next_day]}
        true -> {:cont, acc}
      end
    end)
  end

  # Calculates the day of the week for a given date.
  def day_of_week(date), do: Timex.weekday(date, :sunday)

  # Generates an indexed array of selected days.
  defp selected_days_indexed_array(selected_days) do
    selected_days
    |> Enum.filter(& &1.active)
    |> Enum.with_index()
    |> Enum.map(fn {_map, value} -> value + 1 end)
  end

  # Shifts a date by a specified amount based on the calendar unit.
  defp calendar_shift("week", shift_count, date), do: Timex.shift(date, weeks: shift_count)
  defp calendar_shift("month", shift_count, date), do: Timex.shift(date, months: shift_count)
  defp calendar_shift("year", shift_count, date), do: Timex.shift(date, years: shift_count)

  defp reorder_time_blocks(dates) do
    Enum.map(dates, fn %{time_blocks: time_blocks} = event_date ->
      sorted_time_blocks = Enum.sort_by(time_blocks, &{&1.start_time, &1.end_time})
      %{event_date | time_blocks: sorted_time_blocks}
    end)
  end

  defp shoot_start_at(date, time, time_zone), do: DateTime.new!(date, time, time_zone)
end
