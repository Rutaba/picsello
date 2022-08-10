defmodule Picsello.UserManagesBookingEventsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup :onboarded
  setup :authenticated

  feature "sees empty state", %{session: session} do
    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> assert_text("You don’t have any booking events created at the moment")
  end

  feature "sees list of events", %{session: session, user: user} do
    template = insert(:package_template, user: user, job_type: "mini", name: "My custom package")

    insert(:booking_event,
      name: "Event 1",
      package_template_id: template.id,
      duration_minutes: 45,
      dates: [
        %{
          date: ~D[2050-12-10],
          time_blocks: [
            %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]}
          ]
        }
      ]
    )

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> assert_text("Event 1")
    |> assert_text("My custom package")
    |> assert_text("45 minutes")
    |> assert_text("12/10/2050")
  end

  feature "creates new booking event", %{session: session, user: user} do
    insert(:package_template, user: user, job_type: "wedding")

    template_id =
      insert(:package_template, user: user, job_type: "mini", name: "Mini 1") |> Map.get(:id)

    insert(:package_template, user: user, job_type: "mini", name: "Mini 2")
    bypass = Bypass.open()
    mock_image_upload(bypass)

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> click(link("Add booking event"))
    |> assert_text("Add booking event: Details")
    |> fill_in(text_field("Title"), with: "My event")
    |> find(select("Shoot Location"), &click(&1, option("On Location")))
    |> fill_in(text_field("Shoot Address"), with: "320 1st St N, Jax Beach, FL")
    |> find(select("Session Length"), &click(&1, option("45 mins")))
    |> find(select("Session Buffer"), &click(&1, option("15 mins")))
    |> fill_in(text_field("booking_event[dates][0][date]"), with: "10/10/2050")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][0][start_time]"), with: "09:00AM")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][0][end_time]"), with: "01:00PM")
    |> scroll_into_view(testid("add-date"))
    |> click(button("Add block"))
    |> fill_in(text_field("booking_event[dates][0][time_blocks][1][start_time]"), with: "03:00PM")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][1][end_time]"), with: "05:00PM")
    |> click(button("Add another date"))
    |> assert_has(testid("event-date", count: 2))
    |> scroll_into_view(testid("add-date"))
    |> fill_in(text_field("booking_event[dates][1][date]"), with: "10/11/2050")
    |> fill_in(text_field("booking_event[dates][1][time_blocks][0][start_time]"), with: "09:00AM")
    |> fill_in(text_field("booking_event[dates][1][time_blocks][0][end_time]"), with: "10:00AM")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Add booking event: Select package")
    |> assert_disabled_submit(text: "Next")
    |> assert_has(testid("template-card", count: 2))
    |> click(testid("template-card", text: "Mini 1"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Add booking event: Customize")
    |> assert_disabled_submit(text: "Save")
    |> attach_file(testid("image-upload-input", visible: false),
      path: "assets/static/favicon-128.png"
    )
    |> click(css("div.ql-editor"))
    |> send_keys(["My custom description"])
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_flash(:success, text: "Booking event saved successfully")
    |> assert_path("/booking-events")
    |> assert_text("My event")

    thumbnail_url = "http://localhost:#{bypass.port}/image.jpg"

    assert [
             %{
               name: "My event",
               location: "on_location",
               address: "320 1st St N, Jax Beach, FL",
               duration_minutes: 45,
               buffer_minutes: 15,
               dates: [
                 %{
                   date: ~D[2050-10-10],
                   time_blocks: [
                     %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]},
                     %{start_time: ~T[15:00:00], end_time: ~T[17:00:00]}
                   ]
                 },
                 %{
                   date: ~D[2050-10-11],
                   time_blocks: [%{end_time: ~T[10:00:00], start_time: ~T[09:00:00]}]
                 }
               ],
               package_template_id: ^template_id,
               thumbnail_url: ^thumbnail_url,
               description: "<p>My custom description</p>"
             }
           ] = Picsello.Repo.all(Picsello.BookingEvent)
  end

  feature "validation errors", %{session: session} do
    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> click(link("Add booking event"))
    |> assert_text("Add booking event: Details")
    |> fill_in(text_field("Title"), with: " ")
    |> assert_text("Title can't be blank")
    |> fill_in(text_field("Shoot Address"), with: " ")
    |> assert_text("Shoot Address can't be blank")
    |> fill_in(text_field("booking_event[dates][0][date]"), with: "10/10/2050")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][0][start_time]"), with: "09:00AM")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][0][end_time]"), with: "01:00PM")
    |> scroll_into_view(testid("add-date"))
    |> click(button("Add block"))
    |> fill_in(text_field("booking_event[dates][0][time_blocks][1][start_time]"), with: "11:00AM")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][1][end_time]"), with: "05:00PM")
    |> assert_text("Times can't be overlapping")
    |> click(button("Add another date"))
    |> assert_has(testid("event-date", count: 2))
    |> scroll_into_view(testid("add-date"))
    |> fill_in(text_field("booking_event[dates][1][date]"), with: "10/10/2050")
    |> assert_text("Dates can't be the same")
  end

  feature "removes dates and times", %{session: session} do
    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> click(link("Add booking event"))
    |> assert_text("Add booking event: Details")
    |> assert_has(testid("event-date", count: 1))
    |> fill_in(text_field("booking_event[dates][0][date]"), with: "10/10/2050")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][0][start_time]"), with: "09:00AM")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][0][end_time]"), with: "01:00PM")
    |> assert_has(css("input[type=time]", count: 2))
    |> scroll_into_view(testid("add-date"))
    |> click(button("Add block"))
    |> assert_has(css("input[type=time]", count: 4))
    |> fill_in(text_field("booking_event[dates][0][time_blocks][1][start_time]"), with: "02:00AM")
    |> fill_in(text_field("booking_event[dates][0][time_blocks][1][end_time]"), with: "05:00PM")
    |> click(button("remove time"))
    |> assert_has(css("input[type=time]", count: 2))
    |> assert_value(text_field("booking_event[dates][0][time_blocks][0][start_time]"), "09:00")
    |> assert_value(text_field("booking_event[dates][0][time_blocks][0][end_time]"), "13:00")
    |> click(button("Add another date"))
    |> assert_has(testid("event-date", count: 2))
    |> scroll_into_view(testid("add-date"))
    |> fill_in(text_field("booking_event[dates][1][date]"), with: "12/10/2050")
    |> click(button("remove date"))
    |> assert_has(testid("event-date", count: 1))
    |> assert_value(text_field("booking_event[dates][0][date]"), "2050-10-10")
  end

  defp mock_image_upload(%{port: port} = bypass) do
    upload_url = "http://localhost:#{port}"

    Picsello.PhotoStorageMock
    |> Mox.stub(:params_for_upload, fn options ->
      assert %{key: key, field: %{"content-type" => "image/jpeg"}} = Enum.into(options, %{})
      assert key =~ "favicon-128.jpg"
      %{url: upload_url, fields: %{key: "image.jpg"}}
    end)

    Bypass.expect_once(bypass, "POST", "/", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("Access-Control-Allow-Origin", "*")
      |> Plug.Conn.resp(204, "")
    end)

    Bypass.expect(bypass, "GET", "/image.jpg", fn conn ->
      conn
      |> Plug.Conn.resp(200, "")
    end)
  end
end
