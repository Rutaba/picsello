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
    user: user,
    job: %{shoots: [%{id: shoot1_id}, %{id: shoot2_id}]}
  } do
    token = Phoenix.Token.sign(Endpoint, "USER_ID", user.id)

    res = conn |> get(get_url(conn, token), %{})

    assert res.resp_body |> String.contains?("SUMMARY:Mary Jane Wedding - chute")
    shoot1_uid = "shoot_#{shoot1_id}@picsello.com"
    shoot2_uid = "shoot_#{shoot2_id}@picsello.com"

    assert [
             %ICalendar.Event{summary: "Mary Jane Wedding - chute", uid: ^shoot2_uid},
             %ICalendar.Event{summary: "Mary Jane Wedding - chute", uid: ^shoot1_uid}
           ] = res.resp_body |> ICalendar.from_ics()
  end

  test "does not return booking leads", %{
    conn: conn,
    user: user,
    job: %{shoots: [%{id: shoot1_id}, %{id: shoot2_id}]}
  } do
    template = insert(:package_template, user: user)
    event = insert(:booking_event, package_template_id: template.id)

    archived_booking_lead =
      insert(:lead, user: user, archived_at: DateTime.utc_now(), booking_event_id: event.id)

    insert(:shoot, job: archived_booking_lead, starts_at: DateTime.utc_now())
    booking_lead = insert(:lead, user: user, booking_event_id: event.id)
    insert(:shoot, job: booking_lead, starts_at: DateTime.utc_now())

    token = Phoenix.Token.sign(Endpoint, "USER_ID", user.id)

    res = conn |> get(get_url(conn, token), %{})

    shoot1_uid = "shoot_#{shoot1_id}@picsello.com"
    shoot2_uid = "shoot_#{shoot2_id}@picsello.com"

    assert [
             %ICalendar.Event{uid: ^shoot2_uid},
             %ICalendar.Event{uid: ^shoot1_uid}
           ] = res.resp_body |> ICalendar.from_ics()
  end
end
