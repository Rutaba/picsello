defmodule PicselloWeb.JobLive.Shared.RemoteLiveTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney  
  alias Picsello.Accounts
  
  @token "RoJK07y0nExk1c7i57iXQbgzsZ6mGq"
  describe "render" do
    setup do
      ExVCR.Config.filter_request_headers("Authorization")
      ExVCR.Config.filter_request_options("basic_auth")
      user = insert(:user) |> onboard!
      Accounts.set_user_nylas_code(user, @token)
      %{user: user, password: valid_user_password()}
    end

    test "Get all events", %{conn: conn, user: user} do
      use_cassette "#{__MODULE__}_get_all_events" do
        conn = log_in_user(conn, user)
        calendar = "62zs9nfax6wvkhzo7wj8vfzw7"

        assert [calendar]
               |> NylasCalendar.get_events!(@token)
               |> Enum.map(fn event ->
                 assert event.url != ""
                 assert conn |> get(event.url) |> html_response(200)
               end)
               |> length == 9
      end
    end

    test "Load Remote Event", %{conn: conn, user: user} do
      use_cassette "#{__MODULE__}_show_remote_event" do
        path = "/remote/62zs9nfax6wvkhzo7wj8vfzw7/571k7vwh2nljfwhvou5vire9m"
        conn = conn |> log_in_user(user) |> get(path)

        assert html_response(conn, 200)
        {:ok, _live, html} = live(conn)

        values = %{
          busy: true,
          description: nil,
          end_time: "11:00:00 AM June 13, 2023",
          object: "event",
          owner_email: "zkessin@gmail.com",
          participants: [],
          start_time: "10:00:00 AM June 13, 2023",
          status: "confirmed",
          title: "1:00 pm Israel time / 6:00 am EST",
          updated_at: "12:40:29 PM June 12, 2023"
        }

        values
        |> Map.keys()
        |> Enum.each(fn key ->
          assert html |> find_element("##{key}") |> Floki.text() =~ "#{values[key]}"
        end)
      end
    end
  end

  def find_element(html, selector) when is_binary(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(selector)
  end
end
