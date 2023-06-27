defmodule PicselloWeb.CalendarFeedControllerTest do
  use PicselloWeb.ConnCase, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  alias Picsello.Accounts
  @token "RoJ******************************"
  @params %{
    "end" => "2023-07-09T00:00:00",
    "start" => "2023-05-28T00:00:00",
    "timeZone" => "America/New_York"
  }
  @calendars [
    "79stlqym1yrt4tag6ibh0j7ds",
    "8ltfag8u6webc2k1rx4ipk1gs",
    "1ad8qjrcsqx3uympagccecqga",
    "41epn1sk1p21c140jcpnp7avn",
    "62zs9nfax6wvkhzo7wj8vfzw7"
  ]

  setup do
    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_options("basic_auth")

    %{user: insert(:user) |> onboard!, password: valid_user_password()}
  end

  describe "Calendar Feed" do
    test "Requires user to be logged in", %{conn: conn} do
      path = Routes.calendar_feed_path(conn, :index)
      conn = get(conn, path)
      assert html_response(conn, 302)
    end

    test "renders calendar feed", %{conn: conn, user: user} do
      path = Routes.calendar_feed_path(conn, :index)
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_feed_no_external_calendar" do
        assert [] ==
                 conn
                 |> log_in_user(user)
                 |> get(path, @params)
                 |> json_response(200)
      end
    end

    test "Multi Day Event", %{
      conn: conn,
      user: user
    } do
      path = Routes.calendar_feed_path(conn, :index)

      ExVCR.Config.filter_request_headers("Authorization")
      Accounts.set_user_nylas_code(user, @token)

      Accounts.User.set_nylas_calendars(user, %{
        external_calendar_read_list: [
          "62zs9nfax6wvkhzo7wj8vfzw7"
        ]
      })

      use_cassette "#{__MODULE__}_multiday_event_date_range_one_cal" do
        assert %{
                 "color" => "#585DF6",
                 "end" => "2023-06-23",
                 "start" => "2023-06-20",
                 "title" => "Test Event - XYZZY",
                 "url" =>
                   "/remote/62zs9nfax6wvkhzo7wj8vfzw7/2gk1mnm2a71d4ep22epaniail?request_from=calendar"
               } ==
                 conn
                 |> log_in_user(user)
                 |> get(path, @params)
                 |> json_response(200)
                 |> Enum.find(&(&1["title"] =~ "XYZZY"))
      end
    end

    test "renders calendar feed with calendars shows correct number of items", %{
      conn: conn,
      user: user
    } do
      path = Routes.calendar_feed_path(conn, :index)

      ExVCR.Config.filter_request_headers("Authorization")
      Accounts.set_user_nylas_code(user, @token)

      Accounts.User.set_nylas_calendars(user, %{external_calendar_read_list: @calendars})

      use_cassette "#{__MODULE__}_feed_external_calendar" do
        assert 280 ==
                 conn
                 |> log_in_user(user)
                 |> get(path, @params)
                 |> json_response(200)
                 |> length()
      end
    end

    test "Do not show our events on pull ", %{conn: conn, user: user} do
      path = Routes.calendar_feed_path(conn, :index)

      ExVCR.Config.filter_request_headers("Authorization")
      Accounts.set_user_nylas_code(user, @token)

      Accounts.User.set_nylas_calendars(user, %{external_calendar_read_list: @calendars})
      key = "Picsello Test Event"

      use_cassette "#{__MODULE__}_do_no_show_our_events" do
        refute conn
               |> log_in_user(user)
               |> get(path, @params)
               |> json_response(200)
               |> Enum.map(& &1["title"])
               |> Enum.member?(key)
      end
    end

    test "renders calendar feed with calendars shows data", %{conn: conn, user: user} do
      path = Routes.calendar_feed_path(conn, :index)

      ExVCR.Config.filter_request_headers("Authorization")
      Accounts.set_user_nylas_code(user, @token)
      Accounts.User.set_nylas_calendars(user, %{external_calendar_read_list: @calendars})

      use_cassette "#{__MODULE__}_feed_external_calendar" do
        assert [
                 %{
                   "color" => "#585DF6",
                   "end" => "2023-05-15",
                   "start" => "2023-05-14",
                   "title" => "Mother's Day",
                   "url" =>
                     "/remote/79stlqym1yrt4tag6ibh0j7ds/bs3bz4j7sa1gt8l8fk7aebqrn?request_from=calendar"
                 },
                 %{
                   "color" => "#585DF6",
                   "end" => "2023-05-30",
                   "start" => "2023-05-29",
                   "title" => "Memorial Day",
                   "url" =>
                     "/remote/79stlqym1yrt4tag6ibh0j7ds/2tohhvk9ud0q2uzfrky3779ck?request_from=calendar"
                 },
                 %{
                   "color" => "#585DF6",
                   "end" => "2023-06-02",
                   "start" => "2023-06-01",
                   "title" => "First Day of LGBTQ+ Pride Month",
                   "url" =>
                     "/remote/79stlqym1yrt4tag6ibh0j7ds/eacfc644rcx2ih5lab8iialy8?request_from=calendar"
                 },
                 %{
                   "color" => "#585DF6",
                   "end" => "2023-06-15",
                   "start" => "2023-06-14",
                   "title" => "Flag Day",
                   "url" =>
                     "/remote/79stlqym1yrt4tag6ibh0j7ds/1vjof390o4vnlc9iagj238lr4?request_from=calendar"
                 },
                 %{
                   "color" => "#585DF6",
                   "end" => "2023-06-19",
                   "start" => "2023-06-18",
                   "title" => "Father's Day",
                   "url" =>
                     "/remote/79stlqym1yrt4tag6ibh0j7ds/9ue1o4wb1s574t90fv9cukf90?request_from=calendar"
                 },
                 %{
                   "color" => "#585DF6",
                   "end" => "2023-06-20",
                   "start" => "2023-06-19",
                   "title" => "Juneteenth",
                   "url" =>
                     "/remote/79stlqym1yrt4tag6ibh0j7ds/5wfovcs55l7pw2bs8lccd6jb2?request_from=calendar"
                 }
               ] =
                 conn
                 |> log_in_user(user)
                 |> get(path, @params)
                 |> json_response(200)
                 |> Enum.take(6)
      end
    end
  end
end
