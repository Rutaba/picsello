defmodule PicselloWeb.JobLive.Shared.RemoteLiveTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Picsello.{Repo, Job}
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  alias PicselloWeb.JobLive.Shared.HistoryComponent
  alias Picsello.Accounts

  @token "RoJK07y0nExk1c7i57iXQbgzsZ6mGq"
  describe "render" do
    setup do
      ExVCR.Config.filter_request_headers("Authorization")
      ExVCR.Config.filter_request_options("basic_auth")
      %{user: insert(:user) |> onboard!, password: valid_user_password()}
    end

    test "Load Remote Event", %{conn: conn, user: user} do
      Accounts.set_user_nylas_code(user, @token)

      use_cassette "#{__MODULE__}_show_remote_event" do
        path = "/remote/62zs9nfax6wvkhzo7wj8vfzw7/571k7vwh2nljfwhvou5vire9m"
        conn = conn |> log_in_user(user) |> get(path)

        assert html_response(conn, 200)
        {:ok, live, html} = live(conn)

        values = %{
          busy: true,
          description: nil,
          end_time: "2023-06-13T11:00:00+00:00",
          object: "event",
          owner_email: "zkessin@gmail.com",
          participants: [],
          start_time: "2023-06-13T10:00:00+00:00",
          status: "confirmed",
          title: "1:00 pm Israel time / 6:00 am EST",
          updated_at: "2023-06-12T12:40:29+00:00"
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
