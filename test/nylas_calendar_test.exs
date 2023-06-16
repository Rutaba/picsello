defmodule NylasCalendarTest do
  use Picsello.DataCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  @calendar "62zs9nfax6wvkhzo7wj8vfzw7"
  @token "RoJK07y0nExk1c7i57iXQbgzsZ6mGq"
  setup_all do
    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_options("basic_auth")
    :ok
  end

  @calendar_id "qulli2ad0f0ikawkdnl534oz"
  describe "Basic Calendar tests" do
    @tag :skip
    test "Three day Calendar Event" do
      throw(:not_yet_implemented)
    end

    test "Login Link/2" do
      %{client_id: client_id, redirect_uri: redirect} = Application.get_env(:picsello, :nylas)

      query =
        URI.encode_query(%{
          client_id: client_id,
          response_type: "code",
          scopes: "calendar",
          redirect_uri: redirect
        })

      link = "https://api.nylas.com/oauth/authorize?#{query}"

      # System.cmd("open", [link])
      assert {:ok, ^link} = NylasCalendar.generate_login_link(client_id, redirect)
    end

    test "Login Link/0 test defaults" do
      %{client_id: client_id, redirect_uri: redirect} = Application.get_env(:picsello, :nylas)

      assert {:ok, link} = NylasCalendar.generate_login_link(client_id, redirect)

      assert {:ok, ^link} = NylasCalendar.generate_login_link()
    end

    test "Get Calendar Events" do
      calendars = [
        "79stlqym1yrt4tag6ibh0j7ds",
        "8ltfag8u6webc2k1rx4ipk1gs",
        "1ad8qjrcsqx3uympagccecqga",
        "41epn1sk1p21c140jcpnp7avn",
        "62zs9nfax6wvkhzo7wj8vfzw7"
      ]

      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_get_calendar_events" do
        assert calendars |> NylasCalendar.get_events!(@token) |> length() == 280

        assert %{
                 color: "#585DF6",
                 end: "2023-05-15",
                 start: "2023-05-14",
                 title: "Mother's Day",
                 url:
                   "/remote/79stlqym1yrt4tag6ibh0j7ds/bs3bz4j7sa1gt8l8fk7aebqrn?request_from=calendar"
               } = calendars |> NylasCalendar.get_events!(@token) |> hd()
      end
    end

    test "Check Event are set to the correct timezone (America/New_York)" do
      token = "RoJK0*************************"

      calendar_id = "62zs9nfax6wvkhzo7wj8vfzw7"
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_get_calendar_events_timezone" do
        assert events = NylasCalendar.get_events!([calendar_id], token, "America/New_York")
        assert length(events) > 0

        event1 = %{
          color: "#585DF6",
          end: "2023-06-12T13:00:00-04:00",
          start: "2023-06-12T12:00:00-04:00",
          title: "Noon Event - EST",
          url: "/remote/#{calendar_id}/e08nxn67y9rdj5wxmh4la3dwc?request_from=calendar"
        }

        event2 = %{
          color: "#585DF6",
          end: "2023-06-13T07:00:00-04:00",
          start: "2023-06-13T06:00:00-04:00",
          title: "1:00 pm Israel time / 6:00 am EST",
          url: "/remote/#{calendar_id}/571k7vwh2nljfwhvou5vire9m?request_from=calendar"
        }

        assert Enum.member?(events, event1)
        assert Enum.member?(events, event2)
      end
    end

    test "Get Calendars" do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_get_calendars" do
        assert {:ok, calendars} = NylasCalendar.get_calendars(@token)
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
    end

    test "Create Calendar" do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_create_calendar" do
        NylasCalendar.create_calendar(%{"name" => "My Test Calendar"}, @token)
        assert {:ok, calendars} = NylasCalendar.get_calendars(@token)
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
                 NylasCalendar.add_event(
                   "qulli2ad0f0ikawkdnl534oz",
                   %{
                     "title" => "Meeting",
                     "description" => "Discuss project status",
                     "when" => %{
                       "start_time" => "2023-05-18T14:00:00Z",
                       "end_time" => "2023-05-18T15:00:00Z"
                     }
                   },
                   @token
                 )
      end
    end

    test "Event CRUD" do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_crud" do
        assert {:ok, %{"id" => id}} =
                 NylasCalendar.add_event(
                   @calendar,
                   %{
                     "title" => "Meeting",
                     "description" => "Discuss project status",
                     "when" => %{
                       "start_time" => "2023-05-18T14:00:00Z",
                       "end_time" => "2023-05-18T15:00:00Z"
                     }
                   },
                   @token
                 )

        assert {:ok,
                %{
                  "account_id" => "92kk7fha5ii4aiy4swl74kdeb",
                  "busy" => true,
                  "calendar_id" => "62zs9nfax6wvkhzo7wj8vfzw7",
                  "customer_event_id" => nil,
                  "description" => "Lorem ipsum dolor sit amet, consectetur adipiscing elit",
                  "hide_participants" => false,
                  "ical_uid" => nil,
                  "id" => "973mc09vd93euziwlrh4e4zkw",
                  "job_status_id" => "830gczll0oqbjax60z09leccn",
                  "location" => nil,
                  "message_id" => nil,
                  "object" => "event",
                  "organizer_email" => "zkessin@gmail.com",
                  "organizer_name" => "Zachary Kessin",
                  "owner" => "Zachary Kessin <zkessin@gmail.com>",
                  "participants" => [],
                  "read_only" => false,
                  "reminders" => nil,
                  "status" => "confirmed",
                  "title" => "Meeting version 2",
                  "updated_at" => 1_686_924_674,
                  "visibility" => nil,
                  "when" => %{
                    "end_time" => 1_684_422_000,
                    "object" => "timespan",
                    "start_time" => 1_684_418_400
                  }
                }} =
                 NylasCalendar.update_event(
                   %{
                     "id" => id,
                     "title" => "Meeting version 2",
                     "description" => "Lorem ipsum dolor sit amet, consectetur adipiscing elit"
                   },
                   @token
                 )

        assert {:ok, %{"job_status_id" => "7uf8nro7w57vk6fe61f8le22z"}} =
                 NylasCalendar.delete_event(%{"id" => id}, @token)
      end
    end

    test "Get Events" do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_get_events" do
        {:ok, events} = NylasCalendar.get_events(@calendar_id, @token)
        target_id = "3gcdorp3zvqheegatbzdnjnkd"

        assert events |> Enum.map(& &1["id"]) |> Enum.member?(target_id)
      end
    end
  end
end
