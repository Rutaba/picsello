defmodule NylasCalendarTest do
  use Picsello.DataCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  @token "A77LHd1ubDFRdxU64AwZKIyvN7sDfB"
  setup_all do
    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_options("basic_auth")
    :ok
  end

  @calendar_id "qulli2ad0f0ikawkdnl534oz"
  describe "Basic Calendar tests" do
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
        "62zs9nfax6wvkhzo7wj8vfzw7",
        
      ]

      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_get_calendar_events" do
        assert calendars |> NylasCalendar.get_events!(@token) |> length() == 280
        assert %Picsello.Shoot{} = calendars |> NylasCalendar.get_events!(@token) |> hd() 
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

      #      NylasCalendar.create_calendar(%{"name" => "My Calendar"})
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
