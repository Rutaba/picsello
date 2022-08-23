defmodule Picsello.BookingEvents do
  @moduledoc "context module for booking events"
  alias Picsello.{Repo, BookingEvent}
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
    changeset
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: [:id],
      returning: true
    )
  end

  def get_booking_events(organization_id) do
    organization_id
    |> booking_events_query()
    |> Repo.all()
  end

  def get_booking_event!(organization_id, event_id) do
    organization_id
    |> booking_events_query()
    |> Repo.get!(event_id)
  end

  def available_times(%BookingEvent{} = booking_event, date) do
    duration = (booking_event.duration_minutes + (booking_event.buffer_minutes || 0)) * 60

    case booking_event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        for(
          %{start_time: start_time, end_time: end_time} <- time_blocks,
          available_slots = (Time.diff(end_time, start_time) / duration) |> trunc(),
          slot <- 0..(available_slots - 1),
          available_slots > 0
        ) do
          start_time |> Time.add(duration * slot)
        end
        |> filter_overlapping_shoots(booking_event, date)

      _ ->
        []
    end
  end

  defp filter_overlapping_shoots(slot_times, %BookingEvent{} = booking_event, date) do
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
    |> Enum.filter(fn slot_time ->
      slot_start = DateTime.new!(date, slot_time, user.time_zone)

      slot_end =
        slot_start
        |> DateTime.add(booking_event.duration_minutes * 60)
        |> DateTime.add(booking_event.buffer_minutes * 60 - 1)

      !Enum.any?(shoots, fn shoot ->
        start_time = shoot.starts_at |> DateTime.shift_zone!(user.time_zone)
        end_time = shoot.starts_at |> DateTime.add(shoot.duration_minutes * 60)

        (DateTime.compare(slot_start, start_time) in [:gt, :eq] &&
           DateTime.compare(slot_start, end_time) in [:lt, :eq]) ||
          (DateTime.compare(slot_end, start_time) in [:gt, :eq] &&
             DateTime.compare(slot_end, end_time) in [:lt, :eq])
      end)
    end)
  end

  defp booking_events_query(organization_id) do
    from(event in BookingEvent,
      join: package in assoc(event, :package_template),
      where: package.organization_id == ^organization_id,
      preload: [package_template: package]
    )
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
      package_template
      |> Picsello.Packages.changeset_from_template()
      |> Picsello.Packages.insert_package_and_update_job_multi(job)
    end)
    |> Ecto.Multi.merge(fn %{package: package} ->
      Picsello.Contracts.maybe_add_default_contract_to_package_multi(package)
    end)
    |> Ecto.Multi.insert(:shoot, fn changes ->
      starts_at = DateTime.new!(date, time, photographer.time_zone)

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
    |> Ecto.Multi.insert(:payment_schedule, fn changes ->
      Picsello.PaymentSchedule.create_changeset(%{
        job_id: changes.job.id,
        price: Picsello.Package.price(changes.package),
        due_at: DateTime.utc_now(),
        description: "100% retainer"
      })
    end)
    |> Repo.transaction()
  end
end
