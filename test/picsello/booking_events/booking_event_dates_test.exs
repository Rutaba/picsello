defmodule Picsello.BookingEventDatesTest do
  use Picsello.DataCase, async: true
  alias Picsello.{BookingEventDates, BookingEventDate.SlotBlock}

  describe "create booking_event_date" do
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
          name: "new event",
          organization_id: user.organization_id
        )

      {:ok, user: user, package_template: template, booking_event: booking_event}
    end

    test "create booking_event_date with valid data", %{user: user, booking_event: booking_event} do
      assert {:ok, _booking_event_date} =
               %{
                 date: "2023-10-10",
                 session_length: 30,
                 session_gap: 30,
                 time_blocks: [
                   %{start_time: ~T[10:00:00], end_time: ~T[11:00:00]}
                 ],
                 slots: [
                   %{slot_start: ~T[09:00:00], slot_end: ~T[09:30:00]},
                   %{slot_start: ~T[09:30:00], slot_end: ~T[10:00:00]}
                 ],
                 booking_event_id: booking_event.id,
                 organization_id: user.organization_id
               }
               |> BookingEventDates.create_booking_event_dates()
    end

    test "error creating booking_event_date without date", %{
      user: user,
      booking_event: booking_event
    } do
      assert {:error, _booking_event_date} =
               %{
                 session_length: 30,
                 session_gap: 30,
                 time_blocks: [
                   %{start_time: ~T[10:00:00], end_time: ~T[11:00:00]}
                 ],
                 slots: [
                   %{slot_start: ~T[09:00:00], slot_end: ~T[09:30:00]},
                   %{slot_start: ~T[09:30:00], slot_end: ~T[10:00:00]}
                 ],
                 booking_event_id: booking_event.id,
                 organization_id: user.organization_id
               }
               |> BookingEventDates.create_booking_event_dates()
    end

    test "error creating booking_event_date without session_length", %{
      user: user,
      booking_event: booking_event
    } do
      assert {:error, _booking_event_date} =
               %{
                 date: "2023-10-10",
                 session_gap: 30,
                 time_blocks: [
                   %{start_time: ~T[10:00:00], end_time: ~T[11:00:00]}
                 ],
                 slots: [
                   %{slot_start: ~T[09:00:00], slot_end: ~T[09:30:00]},
                   %{slot_start: ~T[09:30:00], slot_end: ~T[10:00:00]}
                 ],
                 booking_event_id: booking_event.id,
                 organization_id: user.organization_id
               }
               |> BookingEventDates.create_booking_event_dates()
    end

    test "error creating booking_event_date without booking_event_id", %{user: user} do
      assert {:error, _booking_event_date} =
               %{
                 date: "2023-10-10",
                 session_length: 30,
                 session_gap: 30,
                 time_blocks: [
                   %{start_time: ~T[10:00:00], end_time: ~T[11:00:00]}
                 ],
                 slots: [
                   %{slot_start: ~T[09:00:00], slot_end: ~T[09:30:00]},
                   %{slot_start: ~T[09:30:00], slot_end: ~T[10:00:00]}
                 ],
                 organization_id: user.organization_id
               }
               |> BookingEventDates.create_booking_event_dates()
    end

    test "error creating booking_event_date without time_blocks/slot_blocks", %{
      user: user,
      booking_event: booking_event
    } do
      assert {:error, _booking_event_date} =
               %{
                 date: "2023-10-10",
                 session_length: 30,
                 session_gap: 30,
                 slots: [
                   %{slot_start: ~T[09:00:00], slot_end: ~T[09:30:00]},
                   %{slot_start: ~T[09:30:00], slot_end: ~T[10:00:00]}
                 ],
                 booking_event_id: booking_event.id,
                 organization_id: user.organization_id
               }
               |> BookingEventDates.create_booking_event_dates()

      assert {:error, _booking_event_date} =
               %{
                 date: "2023-10-10",
                 session_length: 30,
                 session_gap: 30,
                 time_blocks: [
                   %{start_time: ~T[10:00:00], end_time: ~T[11:00:00]}
                 ],
                 organization_id: user.organization_id
               }
               |> BookingEventDates.create_booking_event_dates()
    end
  end

  describe "transform slots" do
    setup do
      user = insert(:user)

      client_one =
        insert(:client,
          user: user,
          name: "Elizabeth Taylor",
          email: "taylor@example.com",
          phone: "(210) 111-1234"
        )

      client_two =
        insert(:client, %{
          user: user,
          name: "John Snow",
          phone: "(241) 567-2352",
          email: "snow@example.com"
        })

      template =
        insert(:package_template,
          user: user,
          job_type: "mini",
          name: "My custom package"
        )

      booking_event =
        insert(:booking_event,
          name: "test event",
          organization_id: user.organization_id
        )

      booking_event_date =
        insert(:booking_event_date, %{
          date: "2024-10-10",
          session_length: 30,
          time_blocks: [
            %{start_time: ~T[10:00:00], end_time: ~T[11:00:00]}
          ],
          slots: [
            %{
              slot_start: ~T[09:00:00],
              slot_end: ~T[09:30:00],
              status: :reserved,
              client_id: client_one.id
            },
            %{
              slot_start: ~T[09:30:00],
              slot_end: ~T[10:00:00],
              status: :booked,
              client_id: client_two.id
            },
            %{slot_start: ~T[10:00:00], slot_end: ~T[10:30:00]},
            %{slot_start: ~T[10:30:00], slot_end: ~T[11:00:00]}
          ],
          booking_event_id: booking_event.id,
          organization_id: user.organization_id
        })

      {:ok, user: user, package_template: template, booking_event_date: booking_event_date}
    end

    test "transform slots updates the booked/reserved slots to open", %{
      booking_event_date: booking_event_date
    } do
      slots =
        booking_event_date.slots
        |> BookingEventDates.transform_slots()

      assert slots |> Enum.all?(fn slot -> slot.status == :open && is_nil(slot.client_id) end)
    end
  end

  describe "available_slots/2" do
    setup do
      user = insert(:user)

      template =
        insert(:package_template,
          user: user,
          job_type: "mini",
          name: "My custom package"
        )

      client =
        insert(:client,
          user: user,
          name: "Elizabeth Taylor",
          email: "taylor@example.com",
          phone: "(210) 111-1234"
        )

      booking_event =
        insert(:booking_event,
          name: "testing event",
          organization_id: user.organization_id,
          package_template_id: template.id,
          status: :disabled,
          duration_minutes: 30,
          buffer_minutes: 30,
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
            },
            %{
              session_length: 30,
              date: ~D[2050-12-11],
              time_blocks: [
                %{start_time: ~T[10:00:00], end_time: ~T[11:00:00]}
              ],
              slots: [
                %{slot_start: ~T[10:00:00], slot_end: ~T[10:30:00]},
                %{slot_start: ~T[10:30:00], slot_end: ~T[11:00:00]}
              ]
            },
            %{
              session_length: 30,
              date: ~D[2050-12-12],
              time_blocks: [
                %{start_time: ~T[11:00:00], end_time: ~T[12:00:00]}
              ],
              slots: [
                %{
                  slot_start: ~T[11:00:00],
                  slot_end: ~T[11:30:00],
                  status: :booked,
                  client_id: client.id
                },
                %{
                  slot_start: ~T[11:30:00],
                  slot_end: ~T[12:00:00],
                  status: :reserved,
                  client_id: client.id
                }
              ]
            }
          ]
        )

      {:ok, booking_event: booking_event}
    end

    test "returns available slots for booking event", %{booking_event: booking_event} do
      assert [
               [
                 %SlotBlock{
                   slot_start: ~T[09:00:00],
                   slot_end: ~T[09:30:00],
                   client_id: nil,
                   job_id: nil,
                   status: :open,
                   is_hide: false
                 },
                 %SlotBlock{
                   slot_start: ~T[09:30:00],
                   slot_end: ~T[10:00:00],
                   client_id: nil,
                   job_id: nil,
                   status: :open,
                   is_hide: false
                 }
               ],
               [
                 %SlotBlock{
                   slot_start: ~T[10:00:00],
                   slot_end: ~T[10:30:00],
                   client_id: nil,
                   job_id: nil,
                   status: :open,
                   is_hide: false
                 },
                 %SlotBlock{
                   slot_start: ~T[10:30:00],
                   slot_end: ~T[11:00:00],
                   client_id: nil,
                   job_id: nil,
                   status: :open,
                   is_hide: false
                 }
               ],
               [
                 %SlotBlock{
                   slot_start: ~T[11:00:00],
                   slot_end: ~T[11:30:00],
                   client_id: nil,
                   job_id: nil,
                   status: :open,
                   is_hide: false
                 },
                 %SlotBlock{
                   slot_start: ~T[11:30:00],
                   slot_end: ~T[12:00:00],
                   client_id: nil,
                   job_id: nil,
                   status: :open,
                   is_hide: false
                 }
               ]
             ] ==
               Enum.map(booking_event.dates, fn d ->
                 BookingEventDates.available_slots(d, booking_event)
               end)
    end

    test "is_booked_any_date?/2", %{booking_event: booking_event} do
      assert true ==
               BookingEventDates.is_booked_any_date?(
                 [~D[2050-12-11], ~D[2050-12-12]],
                 booking_event.id
               )

      assert false ==
               BookingEventDates.is_booked_any_date?(
                 [~D[2050-12-10], ~D[2050-12-11]],
                 booking_event.id
               )
    end
  end
end
