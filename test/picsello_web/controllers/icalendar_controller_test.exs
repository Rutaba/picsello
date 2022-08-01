defmodule PicselloWeb.ICalendarControllerTest do
  use PicselloWeb.ConnCase, async: true

  alias PicselloWeb.Endpoint

  defp get_url(conn, token), do: Routes.i_calendar_path(conn, :index, token)

  setup do
    user = insert(:user)

    lead =
      insert(:lead,
        package: %{shoot_count: 2, base_price: 2000},
        shoots: [
          %{starts_at: DateTime.utc_now() |> DateTime.add(2 * 24 * 60 * 60)},
          %{starts_at: DateTime.utc_now() |> DateTime.add(3 * 24 * 60 * 60)}
        ],
        user: user
      )

    job = lead |> promote_to_job()

    [user: user, job: job]
  end

  test "icalendar invalid token", %{
    conn: conn
  } do
    assert %Plug.Conn{status: 302, params: %{"token" => "invalid"}} =
             conn |> get(get_url(conn, "invalid"), %{})
  end

  test "icalendar invalid user", %{
    conn: conn
  } do
    token = Phoenix.Token.sign(Endpoint, "USER_ID", 3)
    assert_raise(Ecto.NoResultsError, fn -> conn |> get(get_url(conn, token), %{}) end)
  end

  test "icalendar feed", %{
    conn: conn,
    user: user
  } do
    token = Phoenix.Token.sign(Endpoint, "USER_ID", user.id)

    res = conn |> get(get_url(conn, token), %{})

    assert res.resp_body |> String.contains?("SUMMARY:Mary Jane Wedding - chute")
  end
end
