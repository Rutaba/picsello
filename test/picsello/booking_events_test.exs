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
               {~T[09:00:00.000000], true, _, _},
               {~T[10:00:00.000000], true, _, _},
               {~T[11:00:00.000000], true, _, _},
               {~T[12:00:00.000000], true, _, _},
               {~T[14:00:00.000000], true, _, _}
             ] = BookingEvents.available_times(event, ~D[2050-12-10])
    end

    test "returns available times for events without buffer" do
      user = insert(:user)
      template = insert(:package_template, user: user)

      event =
        insert(:booking_event,
          package_template_id: template.id,
          duration_minutes: 30,
          buffer_minutes: nil,
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
               {~T[09:00:00.000000], _, _, _},
               {~T[09:30:00.000000], _, _, _},
               {~T[10:00:00.000000], _, _, _},
               {~T[10:30:00.000000], _, _, _},
               {~T[11:00:00.000000], _, _, _},
               {~T[11:30:00.000000], _, _, _},
               {~T[12:00:00.000000], _, _, _},
               {~T[12:30:00.000000], _, _, _},
               {~T[14:00:00.000000], _, _, _},
               {~T[14:30:00.000000], _, _, _},
               {~T[16:00:00.000000], _, _, _}
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
               {~T[09:00:00.000000], true, _, _},
               {~T[10:00:00.000000], false, _, _},
               {~T[11:00:00.000000], true, _, _}
             ] = BookingEvents.available_times(event, ~D[2050-12-10])

      assert [
               {~T[09:00:00.000000], _, _, _},
               {~T[10:00:00.000000], _, _, _},
               {~T[11:00:00.000000], _, _, _}
             ] =
               BookingEvents.available_times(event, ~D[2050-12-10], skip_overlapping_shoots: true)
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
               {~T[19:00:00.000000], true, _, _},
               {~T[20:00:00.000000], true, _, _},
               {~T[21:00:00.000000], true, _, _},
               {~T[22:00:00.000000], true, _, _}
             ] = BookingEvents.available_times(event, ~D[2050-12-10])
    end

    test "defaults to 5 min slots when duration is not present" do
      event = %Picsello.BookingEvent{
        dates: [
          %{
            date: ~D[2050-12-10],
            time_blocks: [
              %{start_time: ~T[09:00:00], end_time: ~T[09:30:00]}
            ]
          }
        ]
      }

      assert [
               {~T[09:00:00.000000], _, _, _},
               {~T[09:05:00.000000], _, _, _},
               {~T[09:10:00.000000], _, _, _},
               {~T[09:15:00.000000], _, _, _},
               {~T[09:20:00.000000], _, _, _},
               {~T[09:25:00.000000], _, _, _}
             ] =
               BookingEvents.available_times(event, ~D[2050-12-10], skip_overlapping_shoots: true)
    end

    test "returns empty when time blocks are not set" do
      event = %Picsello.BookingEvent{
        dates: [
          %{
            date: ~D[2050-12-10],
            time_blocks: [
              %{start_time: nil, end_time: nil}
            ]
          }
        ]
      }

      assert [] =
               BookingEvents.available_times(event, ~D[2050-12-10], skip_overlapping_shoots: true)
    end
  end

  describe "expire_booking/1" do
    test "does not archive when lead is already converted to job" do
      lead = insert(:lead) |> promote_to_job()
      assert {:ok, _} = BookingEvents.expire_booking(lead)
      assert %{archived_at: nil} = lead |> Repo.reload()
    end

    test "updates lead archived_at" do
      lead = insert(:lead)
      assert {:ok, _} = BookingEvents.expire_booking(lead)
      assert %{archived_at: %DateTime{}} = lead |> Repo.reload()
    end

    test "expires stripe session when stripe id is set" do
      lead = insert(:lead)
      insert(:payment_schedule, job: lead, stripe_session_id: "session_id")

      Picsello.MockPayments
      |> Mox.stub(:expire_session, fn "session_id", _opts ->
        {:ok, %Stripe.Session{}}
      end)

      assert {:ok, _} = BookingEvents.expire_booking(lead)
    end

    test "does not expires stripe session when stripe id is not set" do
      lead = insert(:lead)
      insert(:payment_schedule, job: lead)
      assert {:ok, _} = BookingEvents.expire_booking(lead)
    end
  end
end
