defmodule Picsello.BookingEvents do
  @moduledoc "context module for booking events"
  alias Picsello.{Repo, BookingEvent, Job, Package}
  import Ecto.Query

  defmodule Booking do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :name, :string
      field :email, :string
      field :phone, :string
      field :date, :date
      field :time, :time
    end

    def changeset(attrs \\ %{}) do
      %__MODULE__{}
      |> cast(attrs, [:name, :email, :phone, :date, :time])
      |> validate_required([:name, :email, :phone, :date, :time])
      |> validate_change(:phone, &valid_phone/2)
    end

    defdelegate valid_phone(field, value), to: Picsello.Client
  end

  def upsert_booking_event(changeset) do
    changeset |> Repo.insert_or_update()
  end

  def get_booking_events_public(organization_id) do
    from(event in BookingEvent,
      join: package in assoc(event, :package_template),
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
        dates: event.dates,
        description: event.description,
        address: event.address,
        package_template: package
      }
    )
    |> Repo.all()
  end

  def get_booking_events(organization_id,
        filters: %{sort_by: sort_by, sort_direction: sort_direction} = opts
      ) do
    from(event in BookingEvent,
      left_join: job in assoc(event, :jobs),
      left_join: status in assoc(job, :job_status),
      join: package in assoc(event, :package_template),
      where: package.organization_id == ^organization_id,
      where: ^filters_search(opts),
      where: ^filters_status(opts),
      select: %{
        booking_count: fragment("sum(case when ?.is_lead = false then 1 else 0 end)", status),
        can_edit?: fragment("count(?.*) = 0", job),
        package_name: package.name,
        id: event.id,
        name: event.name,
        thumbnail_url: event.thumbnail_url,
        status: event.status,
        duration_minutes: event.duration_minutes,
        dates: event.dates
      },
      group_by: [event.id, package.name],
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
    from(event in BookingEvent,
      join: package in assoc(event, :package_template),
      where: package.organization_id == ^organization_id
    )
    |> Repo.get!(event_id)
  end

  def get_booking_event_preload!(organization_id, event_id) do
    from(event in BookingEvent,
      join: package in assoc(event, :package_template),
      where: package.organization_id == ^organization_id,
      preload: [package_template: package]
    )
    |> Repo.get!(event_id)
  end

  def available_times(%BookingEvent{} = booking_event, date, opts \\ []) do
    duration =
      ((booking_event.duration_minutes || Picsello.Shoot.durations() |> hd) +
         (booking_event.buffer_minutes || 0)) * 60

    skip_overlapping_shoots = opts |> Keyword.get(:skip_overlapping_shoots, false)

    case booking_event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        for(
          %{start_time: %Time{} = start_time, end_time: %Time{} = end_time} <-
            time_blocks,
          available_slots = (Time.diff(end_time, start_time) / duration) |> trunc(),
          slot <- 0..(available_slots - 1),
          available_slots > 0
        ) do
          start_time |> Time.add(duration * slot)
        end
        |> filter_overlapping_shoots(booking_event, date, skip_overlapping_shoots)
        |> filter_is_break_slots(booking_event, date)

      _ ->
        []
    end
  end

  def assign_booked_block_dates(dates, %BookingEvent{} = booking_event) do
    dates
    |> Enum.map(fn %{date: date, time_blocks: time_blocks} = block ->
      blocks =
        available_times(booking_event, date)
        |> fetch_blocks(time_blocks)

      block |> Map.put(:time_blocks, blocks)
    end)
  end

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

  def is_blocked_booked(
        %{start_time: start_time, end_time: end_time},
        _slots
      )
      when start_time == nil or end_time == nil,
      do: false

  def is_blocked_booked(
        %{start_time: %Time{} = start_time, end_time: %Time{} = end_time},
        slots
      ) do
    Enum.filter(slots, fn {slot_time, is_available, _is_break, _is_hide} ->
      !is_available && Time.compare(slot_time, start_time) in [:gt, :eq] &&
        Time.compare(slot_time, end_time) in [:lt, :eq]
    end)
    |> Enum.count() > 0
  end

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
              Time.compare(slot_time, end_time) in [:lt, :eq]
          end
        end

      _ ->
        false
    end
  end

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
              Time.compare(slot_time, end_time) in [:lt, :eq]
          end
        end

      _ ->
        false
    end
  end

  defp filter_overlapping_shoots(slot_times, _booking_event, _date, true) do
    slot_times |> Enum.map(fn slot_time -> {slot_time, true, true, true} end)
  end

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
        where: client.organization_id == ^organization.id and is_nil(job.archived_at),
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

  defp is_slot_booked(nil, slot_start, slot_end, start_time, end_time) do
    (DateTime.compare(slot_start, start_time) in [:gt, :eq] &&
       DateTime.compare(slot_start, end_time) == :lt) ||
      (DateTime.compare(slot_end, start_time) in [:gt, :eq] &&
         DateTime.compare(slot_end, end_time) == :lt)
  end

  defp is_slot_booked(_buffer, slot_start, slot_end, start_time, end_time) do
    (DateTime.compare(slot_start, start_time) in [:gt, :eq] &&
       DateTime.compare(slot_start, end_time) in [:lt, :eq]) ||
      (DateTime.compare(slot_end, start_time) in [:gt, :eq] &&
         DateTime.compare(slot_end, end_time) in [:lt, :eq])
  end

  def save_booking(booking_event, %Booking{
        email: email,
        name: name,
        phone: phone,
        date: date,
        time: time
      }) do
    %{package_template: %{organization: %{user: photographer}} = package_template} =
      booking_event
      |> Repo.preload(package_template: [organization: :user])

    starts_at = shoot_start_at(date, time, photographer.time_zone)

    Ecto.Multi.new()
    |> Picsello.Jobs.maybe_upsert_client(
      %Picsello.Client{email: email, name: name, phone: phone},
      photographer
    )
    |> Ecto.Multi.insert(:job, fn changes ->
      Picsello.Job.create_changeset(%{
        type: package_template.job_type,
        client_id: changes.client.id
      })
      |> Ecto.Changeset.put_change(:booking_event_id, booking_event.id)
    end)
    |> Ecto.Multi.merge(fn %{job: job} ->
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

      opts = %{
        payment_schedules: payment_schedules,
        action: :insert,
        total_price: Package.price(package_template)
      }

      package_template
      |> Picsello.Packages.changeset_from_template()
      |> Picsello.Packages.insert_package_and_update_job(job, opts)
    end)
    |> Ecto.Multi.merge(fn %{package: package} ->
      Picsello.Contracts.maybe_add_default_contract_to_package_multi(package)
    end)
    |> Ecto.Multi.insert(:shoot, fn changes ->
      Picsello.Shoot.create_changeset(
        booking_event
        |> Map.take([:name, :duration_minutes, :location, :address])
        |> Map.put(:starts_at, starts_at)
        |> Map.put(:job_id, changes.job.id)
      )
    end)
    |> Ecto.Multi.insert(:proposal, fn changes ->
      Picsello.BookingProposal.create_changeset(%{job_id: changes.job.id})
    end)
    |> Oban.insert(:oban_job, fn changes ->
      # multiply booking reservation by 2 to account for time spent on Stripe checkout
      expiration = Application.get_env(:picsello, :booking_reservation_seconds) * 2
      Picsello.Workers.ExpireBooking.new(%{id: changes.job.id}, schedule_in: expiration)
    end)
    |> Repo.transaction()
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

  def expire_booking(%Job{} = job) do
    with %Job{
           job_status: job_status,
           client: %{organization: organization},
           payment_schedules: payment_schedules
         } <-
           job |> Repo.preload([:payment_schedules, :job_status, client: :organization]),
         %Picsello.JobStatus{is_lead: true} <- job_status,
         {:ok, _} <- Picsello.Jobs.archive_job(job) do
      for %{stripe_session_id: "" <> session_id} <- payment_schedules,
          do:
            Picsello.Payments.expire_session(session_id,
              connect_account: organization.stripe_account_id
            )

      {:ok, job}
    else
      %Picsello.JobStatus{is_lead: false} -> {:ok, job}
      {:error, error} -> {:error, error}
    end
  end

  defp shoot_start_at(date, time, time_zone), do: DateTime.new!(date, time, time_zone)
end
