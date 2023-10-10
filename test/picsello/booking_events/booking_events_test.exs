defmodule Picsello.BookingEventsTest do
  use Picsello.DataCase, async: true
  alias Picsello.{BookingEvents, Repo}

  describe "create booking_event" do
    setup do
      user = insert(:user)

      template =
        insert(:package_template,
          user: user,
          job_type: "mini",
          name: "My custom package"
        )

      {:ok, user: user, package_template: template}
    end

    test "creating booking_event", %{user: user} do
      assert {:ok, _booking_event} =
               %{
                 name: "testing event",
                 duration_minutes: 30,
                 buffer_minutes: 30,
                 organization_id: user.organization_id
               }
               |> BookingEvents.create_booking_event()
    end

    test "error creating booking_event because no organization id" do
      {:error, changeset} =
        %{
          name: "testing event",
          duration_minutes: 30,
          buffer_minutes: 30
        }
        |> BookingEvents.create_booking_event()

      assert changeset.errors == [organization_id: {"can't be blank", [validation: :required]}]
    end

    test "error creating booking_event because no name", %{user: user} do
      {:error, changeset} =
        %{
          duration_minutes: 30,
          buffer_minutes: 30,
          organization_id: user.organization_id
        }
        |> BookingEvents.create_booking_event()

      assert changeset.errors == [name: {"can't be blank", [validation: :required]}]
    end
  end

  describe "duplicate booking_event" do
    setup do
      user = insert(:user)

      template =
        insert(:package_template,
          user: user,
          job_type: "mini",
          name: "My custom package"
        )

      booking_event =
        insert(:booking_event,
          name: "testing event",
          organization_id: user.organization_id,
          package_template_id: template.id,
          status: :disabled,
          dates: [
            %{
              session_length: 30,
              date: ~D[2050-12-10],
              time_blocks: [
                %{start_time: ~T[09:00:00], end_time: ~T[10:00:00]}
              ],
              slots: [
                %{slot_start: ~T[09:00:00], slot_end: ~T[09:30:00]},
                %{slot_start: ~T[09:30:00], slot_end: ~T[10:00:00]}
              ]
            }
          ]
        )
        |> Map.from_struct()

      booking_event_without_timeblocks =
        insert(:booking_event,
          name: "testing event",
          organization_id: user.organization_id,
          package_template_id: template.id,
          status: :disabled
        )
        |> Map.from_struct()

      {:ok,
       user: user,
       package_template: template,
       booking_event: booking_event,
       booking_event_without_timeblocks: booking_event_without_timeblocks}
    end

    test "duplicate booking event created", %{booking_event: booking_event, user: user} do
      {:ok, %{duplicate_booking_event: duplicate_event}} =
        BookingEvents.duplicate_booking_event(booking_event.id, user.organization_id)

      duplicate_event = Repo.preload(duplicate_event, :dates)
      duplicate_event_dates = hd(duplicate_event.dates)

      # duplicated event status would be active
      assert duplicate_event.status == :active

      # time blocks duplicated
      assert duplicate_event_dates.time_blocks == duplicate_event_dates.time_blocks

      # slots duplicated
      assert duplicate_event_dates.slots == duplicate_event_dates.slots

      # dates not duplicated
      assert is_nil(duplicate_event_dates.date)
    end

    test "duplicate booking_event without timeblocks and slots", %{
      booking_event_without_timeblocks: booking_event,
      user: user
    } do
      {:ok, %{duplicate_booking_event: duplicate_event}} =
        BookingEvents.duplicate_booking_event(booking_event.id, user.organization_id)

      # event duplicated
      assert duplicate_event = booking_event
    end

    test "error duplicating booking event because no package", %{user: user} do
      booking_event =
        insert(:booking_event,
          name: "testing event",
          organization_id: user.organization_id
        )
        |> Map.from_struct()

      {:error, :duplicate_booking_event, changeset, _s} =
        BookingEvents.duplicate_booking_event(booking_event.id, user.organization_id)

      # error that booking event was not created
      assert changeset.errors == [
               package_template_id: {"can't be blank", [validation: :required]}
             ]
    end
  end

  describe "actions for booking_event" do
    setup do
      user = insert(:user)

      booking_event =
        insert(:booking_event,
          name: "testing event",
          duration_minutes: 30,
          buffer_minutes: 30,
          organization_id: user.organization_id,
          status: :active
        )

      {:ok, user: user, booking_event: booking_event}
    end

    test "disable a booking event", %{user: user, booking_event: booking_event} do
      {:ok, updated_event} =
        BookingEvents.disable_booking_event(booking_event.id, user.organization_id)

      assert updated_event.status == :disabled
    end

    test "archive a booking event", %{user: user, booking_event: booking_event} do
      {:ok, updated_event} =
        BookingEvents.archive_booking_event(booking_event.id, user.organization_id)

      assert updated_event.status == :archive
    end

    test "enable a disabled booking event", %{user: user, booking_event: booking_event} do
      # event disabled
      {:ok, updated_event} =
        BookingEvents.disable_booking_event(booking_event.id, user.organization_id)

      {:ok, updated_event} =
        BookingEvents.enable_booking_event(updated_event.id, user.organization_id)

      assert updated_event.status == :active
    end

    test "enable a archived booking event", %{user: user, booking_event: booking_event} do
      # event archived
      {:ok, updated_event} =
        BookingEvents.archive_booking_event(booking_event.id, user.organization_id)

      {:ok, updated_event} =
        BookingEvents.enable_booking_event(updated_event.id, user.organization_id)

      assert updated_event.status == :active
    end
  end
end
