defmodule NylasCalendarTest do
  use Picsello.DataCase

  describe "Basic Calendar tests" do
    test "Get Calendars" do
      throw(:NYI)
      NylasCalendar.get_calendars()
      NylasCalendar.create_calendar(%{"name" => "My Calendar"})
    end

    test "Add Event" do
      throw(:NYI)

      NylasCalendar.add_event("calendar_id", %{
        "title" => "Meeting",
        "description" => "Discuss project status",
        "when" => %{
          "start_time" => "2023-05-17T14:00:00Z",
          "end_time" => "2023-05-17T15:00:00Z"
        }
      })
    end

    test "Get Events" do
      throw(:NYI)
      NylasCalendar.get_events("calendar_id")
    end
  end
end
