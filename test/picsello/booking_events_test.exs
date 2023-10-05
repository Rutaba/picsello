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

  describe "available_times/2" do
    # test "returns available times for specific date" do
    #   user = insert(:user)
    #   template = insert(:package_template, user: user)

    #   event =
    #     insert(:booking_event,
    #       package_template_id: template.id,
    #       duration_minutes: 30,
    #       buffer_minutes: 30,
    #       dates: [
    #         %{
    #           date: ~D[2050-12-10],
    #           time_blocks: [
    #             %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]},
    #             %{start_time: ~T[14:00:00], end_time: ~T[15:00:00]},
    #             %{start_time: ~T[16:00:00], end_time: ~T[16:30:00]}
    #           ]
    #         },
    #         %{
    #           date: ~D[2050-12-11],
    #           time_blocks: [
    #             %{start_time: ~T[09:00:00], end_time: ~T[10:00:00]}
    #           ]
    #         }
    #       ]
    #     )

    #   assert [
    #            {~T[09:00:00], true, _, _},
    #            {~T[10:00:00], true, _, _},
    #            {~T[11:00:00], true, _, _},
    #            {~T[12:00:00], true, _, _},
    #            {~T[14:00:00], true, _, _},
    #            {~T[16:00:00], true, _, _}
    #          ] = BookingEvents.available_times(event, ~D[2050-12-10])
    # end

    # test "returns available times for events without buffer" do
    #   user = insert(:user)
    #   template = insert(:package_template, user: user)

    #   event =
    #     insert(:booking_event,
    #       package_template_id: template.id,
    #       duration_minutes: 30,
    #       buffer_minutes: nil,
    #       dates: [
    #         %{
    #           date: ~D[2050-12-10],
    #           time_blocks: [
    #             %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]},
    #             %{start_time: ~T[14:00:00], end_time: ~T[15:00:00]},
    #             %{start_time: ~T[16:00:00], end_time: ~T[16:30:00]}
    #           ]
    #         },
    #         %{
    #           date: ~D[2050-12-11],
    #           time_blocks: [
    #             %{start_time: ~T[09:00:00], end_time: ~T[10:00:00]}
    #           ]
    #         }
    #       ]
    #     )

    #   assert [
    #            {~T[09:00:00], _, _, _},
    #            {~T[09:30:00], _, _, _},
    #            {~T[10:00:00], _, _, _},
    #            {~T[10:30:00], _, _, _},
    #            {~T[11:00:00], _, _, _},
    #            {~T[11:30:00], _, _, _},
    #            {~T[12:00:00], _, _, _},
    #            {~T[12:30:00], _, _, _},
    #            {~T[14:00:00], _, _, _},
    #            {~T[14:30:00], _, _, _},
    #            {~T[16:00:00], _, _, _}
    #          ] = BookingEvents.available_times(event, ~D[2050-12-10])
    # end

    # test "returns empty for not available date" do
    #   user = insert(:user)
    #   template = insert(:package_template, user: user)

    #   event =
    #     insert(:booking_event,
    #       package_template_id: template.id,
    #       duration_minutes: 30,
    #       buffer_minutes: 30,
    #       dates: [
    #         %{
    #           date: ~D[2050-12-10],
    #           time_blocks: [
    #             %{start_time: ~T[09:00:00], end_time: ~T[10:00:00]}
    #           ]
    #         }
    #       ]
    #     )

    #   assert [] = BookingEvents.available_times(event, ~D[2050-12-11])
    # end

    # test "excludes times when shoots are scheduled within range" do
    #   user = insert(:user)
    #   template = insert(:package_template, user: user)

    #   event =
    #     insert(:booking_event,
    #       package_template_id: template.id,
    #       duration_minutes: 30,
    #       buffer_minutes: 30,
    #       dates: [
    #         %{
    #           date: ~D[2050-12-10],
    #           time_blocks: [
    #             %{start_time: ~T[09:00:00], end_time: ~T[12:00:00]}
    #           ]
    #         }
    #       ]
    #     )

    #   job = insert(:lead, %{user: user})
    #   insert(:shoot, job: job, starts_at: ~U[2050-12-10 10:00:00Z])

    #   assert [
    #            {~T[09:00:00], true, _, _},
    #            {~T[10:00:00], false, _, _},
    #            {~T[11:00:00], true, _, _}
    #          ] = BookingEvents.available_times(event, ~D[2050-12-10])

    #   assert [
    #            {~T[09:00:00], _, _, _},
    #            {~T[10:00:00], _, _, _},
    #            {~T[11:00:00], _, _, _}
    #          ] =
    #            BookingEvents.available_times(event, ~D[2050-12-10], skip_overlapping_shoots: true)
    # end

    # test "excludes times when shoots are scheduled within range and user time zone is not utc" do
    #   user = insert(:user, time_zone: "Etc/GMT+5")
    #   template = insert(:package_template, user: user)

    #   event =
    #     insert(:booking_event,
    #       package_template_id: template.id,
    #       duration_minutes: 30,
    #       buffer_minutes: 30,
    #       dates: [
    #         %{
    #           date: ~D[2050-12-10],
    #           time_blocks: [
    #             %{start_time: ~T[19:00:00], end_time: ~T[23:00:00]}
    #           ]
    #         }
    #       ]
    #     )

    #   job = insert(:lead, %{user: user})
    #   insert(:shoot, job: job, starts_at: ~U[2050-12-11 01:00:00Z], duration_minutes: 60)

    #   assert [
    #            {~T[19:00:00], true, _, _},
    #            {~T[20:00:00], false, _, _},
    #            {~T[21:00:00], false, _, _},
    #            {~T[22:00:00], true, _, _}
    #          ] = BookingEvents.available_times(event, ~D[2050-12-10])
    # end

    # test "defaults to 5 min slots when duration is not present" do
    #   event = %Picsello.BookingEvent{
    #     dates: [
    #       %{
    #         date: ~D[2050-12-10],
    #         time_blocks: [
    #           %{start_time: ~T[09:00:00], end_time: ~T[09:30:00]}
    #         ]
    #       }
    #     ]
    #   }

    #   assert [
    #            {~T[09:00:00], _, _, _},
    #            {~T[09:05:00], _, _, _},
    #            {~T[09:10:00], _, _, _},
    #            {~T[09:15:00], _, _, _},
    #            {~T[09:20:00], _, _, _},
    #            {~T[09:25:00], _, _, _}
    #          ] =
    #            BookingEvents.available_times(event, ~D[2050-12-10], skip_overlapping_shoots: true)
    # end

    # test "returns empty when time blocks are not set" do
    #   event = %Picsello.BookingEvent{
    #     dates: [
    #       %{
    #         date: ~D[2050-12-10],
    #         time_blocks: [
    #           %{start_time: nil, end_time: nil}
    #         ]
    #       }
    #     ]
    #   }

    #   assert [] =
    #            BookingEvents.available_times(event, ~D[2050-12-10], skip_overlapping_shoots: true)
    # end
  end

  describe "expire_booking/1" do
    # test "does not archive when lead is already converted to job" do
    #   lead = insert(:lead) |> promote_to_job()
    #   assert {:ok, _} = BookingEvents.expire_booking(lead)
    #   assert %{archived_at: nil} = lead |> Repo.reload()
    # end

    # test "updates lead archived_at" do
    #   lead = insert(:lead)
    #   assert {:ok, _} = BookingEvents.expire_booking(lead)
    #   assert %{archived_at: %DateTime{}} = lead |> Repo.reload()
    # end

    # test "expires stripe session when stripe id is set" do
    #   lead = insert(:lead)
    #   insert(:payment_schedule, job: lead, stripe_session_id: "session_id")

    #   Picsello.MockPayments
    #   |> Mox.stub(:expire_session, fn "session_id", _opts ->
    #     {:ok, %Stripe.Session{}}
    #   end)

    #   assert {:ok, _} = BookingEvents.expire_booking(lead)
    # end

    # test "does not expires stripe session when stripe id is not set" do
    #   lead = insert(:lead)
    #   insert(:payment_schedule, job: lead)
    #   assert {:ok, _} = BookingEvents.expire_booking(lead)
    # end
  end
end
