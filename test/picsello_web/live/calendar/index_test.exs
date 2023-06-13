defmodule PicselloWeb.Live.Calendar.IndexTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  # alias PicselloWeb.Endpoint
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  alias Picsello.Accounts
  @token "RoJK07y0nExk1c7i57iXQbgzsZ6mGq"

  setup do
    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_options("basic_auth")

    %{user: insert(:user) |> onboard!, password: valid_user_password()}
  end

  test "Load Page", %{conn: conn, user: user} do
    {:ok, _view, _html} = load_page(conn, user)
  end

  test "Load Calendar", %{conn: conn, user: user} do
    path = Routes.calendar_feed_path(conn, :index)

    use_cassette "#{__MODULE__}_load_calendars" do
      calendars = [
        "1ad8qjrcsqx3uympagccecqga",
        "41epn1sk1p21c140jcpnp7avn",
        "62zs9nfax6wvkhzo7wj8vfzw7",
        "79stlqym1yrt4tag6ibh0j7ds",
        "8ltfag8u6webc2k1rx4ipk1gs",
        "bctr87mnash8uypwwfv20ll4a",
        "f0d1wsvqhkeoyc96czki44mv9",
        "l71x8rz1pqrh1qj4pibtjpy5",
        "o6wzom3li5lk2i72kaia5pmj"
      ]

      user
      |> Accounts.set_user_nylas_code(@token)
      |> Picsello.Accounts.User.set_nylas_calendars(%{external_calendar_read_list: calendars})

      conn =
        conn
        |> log_in_user(user)
        |> get(path, %{
          "end" => "2023-07-09T00:00:00",
          "start" => "2023-05-28T00:00:00",
          "timeZone" => "America/New_York"
        })

      assert json_response(conn, 200)
    end
  end
  
  def element_present?(html, selector) do
    html
    |> Floki.parse_document!()
    |> Floki.find(selector) !=
      []
  end

  def find_element(html, selector) when is_binary(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(selector)
  end

  def find_element(view, selector) do
    view |> render() |> find_element(selector)
  end

  def load_page(conn, user) do
    conn =
      conn
      |> log_in_user(user)
      |> get("/calendar/")

    assert html_response(conn, 200)

    live(conn)
  end

  def load_page(conn, user, :token) do
    Accounts.set_user_nylas_code(user, @token)

    conn =
      conn
      |> log_in_user(user)
      |> get("/calendar/")

    assert html_response(conn, 200)

    live(conn)
  end
end
