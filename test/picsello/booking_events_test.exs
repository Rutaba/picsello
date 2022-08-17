defmodule Picsello.BookingEventsTest do
  use Picsello.DataCase, async: true
  alias Picsello.{BookingEvents}

  describe "available_times/2" do
    test "returns available times for specific date" do
      user = insert(:user)
      template = insert(:package_template, user: user)

      event =
        insert(:booking_event,
          package_template_id: template.id,
          duration_minutes: 30,
          buffer_minutes: 30,
          dates: [
            %{
              date: ~D[2050-12-10],
              time_blocks: [
                %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]},
                %{start_time: ~T[14:00:00], end_time: ~T[15:00:00]},
                %{start_time: ~T[16:00:00], end_time: ~T[16:30:00]}
              ]
            },
            %{
              date: ~D[2050-12-11],
              time_blocks: [
                %{start_time: ~T[09:00:00], end_time: ~T[10:00:00]}
              ]
            }
          ]
        )

      assert [
               ~T[09:00:00.000000],
               ~T[10:00:00.000000],
               ~T[11:00:00.000000],
               ~T[12:00:00.000000],
               ~T[14:00:00.000000]
             ] = BookingEvents.available_times(event, ~D[2050-12-10])
    end

    test "returns empty for not available date" do
      user = insert(:user)
      template = insert(:package_template, user: user)

      event =
        insert(:booking_event,
          package_template_id: template.id,
          duration_minutes: 30,
          buffer_minutes: 30,
          dates: [
            %{
              date: ~D[2050-12-10],
              time_blocks: [
                %{start_time: ~T[09:00:00], end_time: ~T[10:00:00]}
              ]
            }
          ]
        )

      assert [] = BookingEvents.available_times(event, ~D[2050-12-11])
    end

    test "excludes times when shoots are scheduled within range" do
      user = insert(:user)
      template = insert(:package_template, user: user)

      event =
        insert(:booking_event,
          package_template_id: template.id,
          duration_minutes: 30,
          buffer_minutes: 30,
          dates: [
            %{
              date: ~D[2050-12-10],
              time_blocks: [
                %{start_time: ~T[09:00:00], end_time: ~T[12:00:00]}
              ]
            }
          ]
        )

      job = insert(:lead, %{user: user})
      insert(:shoot, job: job, starts_at: ~U[2050-12-10 10:00:00.000000Z])

      assert [
               ~T[09:00:00.000000],
               ~T[11:00:00.000000]
             ] = BookingEvents.available_times(event, ~D[2050-12-10])
    end

    test "excludes times when shoots are scheduled within range and user time zone is not utc" do
      user = insert(:user, time_zone: "Etc/GMT+5")
      template = insert(:package_template, user: user)

      event =
        insert(:booking_event,
          package_template_id: template.id,
          duration_minutes: 30,
          buffer_minutes: 30,
          dates: [
            %{
              date: ~D[2050-12-10],
              time_blocks: [
                %{start_time: ~T[19:00:00], end_time: ~T[23:00:00]}
              ]
            }
          ]
        )

      job = insert(:lead, %{user: user})
      insert(:shoot, job: job, starts_at: ~U[2050-12-11 01:00:00.000000Z], duration_minutes: 60)

      assert [
               ~T[19:00:00.000000],
               ~T[22:00:00.000000]
             ] = BookingEvents.available_times(event, ~D[2050-12-10])
    end
  end
end
