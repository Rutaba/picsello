defmodule NylasCalendarTest do
  use Picsello.DataCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_options("basic_auth")
    :ok
  end

  describe "Basic Calendar tests" do
    test "Get Calendars" do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_get_calendars" do
        assert {:ok, calendars} = NylasCalendar.get_calendars()
        assert length(calendars) == 21

        assert [
                 %{
                   "account_id" => "34j115o9vmt50d1ccupayy2lc",
                   "description" => "Emailed events",
                   "id" => "2d004azt2z55bqxvs90gyke1q",
                   "is_primary" => nil,
                   "location" => nil,
                   "name" => "Emailed events",
                   "object" => "calendar",
                   "read_only" => true,
                   "timezone" => nil
                 }
                 | _
               ] = calendars
      end

      #      NylasCalendar.create_calendar(%{"name" => "My Calendar"})
    end

    test "Create Calendar" do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_create_calendar" do
        NylasCalendar.create_calendar(%{"name" => "My Test Calendar"})
        assert {:ok, calendars} = NylasCalendar.get_calendars()
        [new_cal | _] = Enum.reverse(calendars)
        assert new_cal["name"] == "My Test Calendar"
      end
    end

    test "Add Event" do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_add_event" do
        assert {:ok,
                %{
                  "account_id" => "34j115o9vmt50d1ccupayy2lc",
                  "busy" => true,
                  "calendar_id" => "qulli2ad0f0ikawkdnl534oz",
                  "customer_event_id" => nil,
                  "description" => "Discuss project status",
                  "hide_participants" => false,
                  "ical_uid" => nil,
                  "id" => "3gcdorp3zvqheegatbzdnjnkd",
                  "job_status_id" => "9gb6c4d25jc613qp3ndk1z8rk",
                  "location" => nil,
                  "message_id" => nil,
                  "object" => "event",
                  "organizer_email" => "zkessin@gmail.com",
                  "organizer_name" => nil,
                  "owner" => "zkessin@gmail.com <zkessin@gmail.com>",
                  "participants" => [],
                  "read_only" => false,
                  "reminders" => nil,
                  "status" => "confirmed",
                  "title" => "Meeting",
                  "updated_at" => 1_684_340_809,
                  "visibility" => nil,
                  "when" => %{
                    "end_time" => 1_684_422_000,
                    "object" => "timespan",
                    "start_time" => 1_684_418_400
                  }
                }} =
                 NylasCalendar.add_event("qulli2ad0f0ikawkdnl534oz", %{
                   "title" => "Meeting",
                   "description" => "Discuss project status",
                   "when" => %{
                     "start_time" => "2023-05-18T14:00:00Z",
                     "end_time" => "2023-05-18T15:00:00Z"
                   }
                 })
      end
    end

    @tag :skip
    test "Get Events" do
      throw(:NYI)
      NylasCalendar.get_events("calendar_id")
    end
  end
end
