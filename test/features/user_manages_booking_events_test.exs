defmodule Picsello.UserManagesBookingEventsTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true
  require Ecto.Query
  alias Picsello.{Repo, Organization}

  setup :onboarded
  setup :authenticated

  feature "sees empty state", %{session: session} do
    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> assert_text("Meet Client Booking")
  end

  feature "sees list of events", %{session: session, user: user} do
    template = insert(:package_template, user: user, job_type: "mini", name: "My custom package")

    event =
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
    |> assert_text("0 bookings so far")
    |> assert_has(css("button[data-clipboard-text*='/event/#{event.id}']", text: "Copy link"))
    |> assert_has(css("a[href*='/event/#{event.id}']", text: "Preview"))

    insert(:lead, user: user, booking_event_id: event.id) |> promote_to_job()
    insert(:lead, user: user, booking_event_id: event.id)

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> assert_text("1 booking so far")
  end

  feature "creates new booking event", %{session: session, user: user} do
    Repo.update_all(Organization, set: [stripe_account_id: "stripe_id"])

    Mox.stub(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)

    insert(:package_template, user: user, job_type: "wedding", show_on_public_profile: true)

    template_id =
      insert(:package_template,
        user: user,
        job_type: "mini",
        name: "Mini 1",
        shoot_count: 1,
        show_on_public_profile: true
      )
      |> Map.get(:id)

    insert(:package_template,
      user: user,
      job_type: "mini",
      name: "Mini 2",
      shoot_count: 2,
      show_on_public_profile: true
    )

    insert(:package_template,
      user: user,
      job_type: "portrait",
      name: "Portrait 1",
      shoot_count: 1,
      show_on_public_profile: true
    )

    bypass = Bypass.open()
    mock_image_upload(bypass)

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> click(link("Add booking event", count: 2, at: 1))
    |> assert_text("Add booking event: Details")
    |> fill_in(text_field("Title"), with: "My event")
    |> find(select("Shoot Location"), &click(&1, option("On Location")))
    |> fill_in(text_field("Shoot Address"), with: "320 1st St N, Jax Beach, FL")
    |> find(select("Session Length"), &click(&1, option("45 mins")))
    |> find(select("Session Buffer"), &click(&1, option("15 mins")))
    |> scroll_into_view(testid("add-date"))
    |> assert_has(testid("open-slots-count-0", text: "You’ll have 0 open slots"))
    |> click(css("#form-details_dates_0_date"))
    |> fill_in(css("#form-details_dates_0_date"), with: "10-10-2050")
    |> fill_in(css("#form-details_dates_0_time_blocks_0_start_time"), with: "13:00")
    |> fill_in(css("#form-details_dates_0_time_blocks_0_end_time"), with: "14:00")
    |> assert_has(testid("open-slots-count-0", text: "You’ll have 1 open slot"))
    |> click(button("Add block"))
    |> fill_in(css("#form-details_dates_0_time_blocks_1_start_time"), with: "15:00")
    |> fill_in(css("#form-details_dates_0_time_blocks_1_end_time"), with: "17:00")
    |> assert_has(testid("open-slots-count-0", text: "You’ll have 3 open slots"))
    |> click(button("Add another date"))
    |> assert_has(testid("event-date", count: 2))
    |> scroll_into_view(testid("add-date"))
    |> click(css("#form-details_dates_1_date"))
    |> fill_in(css("#form-details_dates_1_date"), with: "11-10-2050")
    |> fill_in(css("#form-details_dates_1_time_blocks_0_start_time"), with: "13:00")
    |> fill_in(css("#form-details_dates_1_time_blocks_0_end_time"), with: "14:00")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> scroll_to_top()
    |> assert_text("Add booking event: Select package")
    |> assert_disabled_submit(text: "Next")
    |> assert_has(testid("template-card", count: 2))
    |> assert_text("Portrait 1")
    |> click(testid("template-card", text: "Mini 1"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Add booking event: Customize")
    |> assert_disabled_submit(text: "Save")
    |> attach_file(testid("image-upload-input", visible: false),
      path: "assets/static/favicon-128.png"
    )
    |> fill_in_quill("My custom description")
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
               status: :active,
               dates: [
                 %{
                   date: ~D[2050-10-10],
                   time_blocks: [
                     %{
                       start_time: ~T[13:00:00],
                       end_time: ~T[14:00:00],
                       is_hidden: false,
                       is_break: false,
                       is_booked: false,
                       is_valid: true
                     },
                     %{
                       start_time: ~T[15:00:00],
                       end_time: ~T[17:00:00],
                       is_hidden: false,
                       is_break: false,
                       is_booked: false,
                       is_valid: true
                     }
                   ]
                 },
                 %{
                   # please don't make it ~D[2050-10-11]. it will stop working on staging
                   date: ~D[2050-11-10],
                   time_blocks: [
                     %{
                       end_time: ~T[14:00:00],
                       start_time: ~T[13:00:00],
                       is_hidden: false,
                       is_break: false,
                       is_booked: false,
                       is_valid: true
                     }
                   ]
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
    |> click(link("Add booking event", count: 2, at: 1))
    |> assert_text("Add booking event: Details")
    |> fill_in(text_field("Title"), with: " ")
    |> assert_text("Title can't be blank")
    |> fill_in(text_field("Shoot Address"), with: " ")
    |> assert_text("Shoot Address can't be blank")
    |> scroll_into_view(testid("add-date"))
    |> click(css("#form-details_dates_0_date"))
    |> fill_in(css("#form-details_dates_0_date"), with: "10-10-2050")
    |> fill_in(css("#form-details_dates_0_time_blocks_0_start_time"), with: "13:00")
    |> fill_in(css("#form-details_dates_0_time_blocks_0_end_time"), with: "15:00")
    |> scroll_into_view(testid("add-date"))
    |> click(button("Add block"))
    |> fill_in(css("#form-details_dates_0_time_blocks_1_start_time"), with: "13:00")
    |> fill_in(css("#form-details_dates_0_time_blocks_1_end_time"), with: "15:00")
    |> assert_text("Times can't be overlapping")
    |> scroll_into_view(testid("add-date"))
    |> click(button("Add another date"))
    |> assert_has(testid("event-date", count: 2))
    |> click(css("#form-details_dates_1_date"))
    |> fill_in(css("#form-details_dates_1_date"), with: "10-10-2050")
    |> scroll_into_view(css("h2", text: "Event date(s)"))
    |> assert_text("Dates can't be the same")
  end

  feature "removes dates and times", %{session: session} do
    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> click(link("Add booking event", count: 2, at: 1))
    |> assert_text("Add booking event: Details")
    |> assert_has(testid("event-date", count: 1))
    |> scroll_into_view(testid("add-date"))
    |> click(css("#form-details_dates_0_date"))
    |> fill_in(css("#form-details_dates_0_date"), with: "10-10-2050")
    |> fill_in(css("#form-details_dates_0_time_blocks_0_start_time"), with: "13:00")
    |> fill_in(css("#form-details_dates_0_time_blocks_0_end_time"), with: "15:00")
    |> scroll_into_view(testid("add-date"))
    |> click(button("Add block"))
    |> fill_in(css("#form-details_dates_0_time_blocks_1_start_time"), with: "13:00")
    |> fill_in(css("#form-details_dates_0_time_blocks_1_end_time"), with: "15:00")
    |> click(testid("remove-time-1"))
    |> click(button("Add block"))
    |> fill_in(css("#form-details_dates_0_time_blocks_1_start_time"), with: "13:00")
    |> fill_in(css("#form-details_dates_0_time_blocks_1_end_time"), with: "15:00")
    |> scroll_into_view(testid("add-date"))
    |> click(button("Add another date"))
    |> assert_has(testid("event-date", count: 2))
    |> scroll_into_view(testid("add-date"))
    |> click(css("#form-details_dates_1_date"))
    |> fill_in(css("#form-details_dates_1_date"), with: "10-10-2050")
    |> click(button("Remove"))
    |> assert_has(testid("event-date", count: 1))
    |> assert_has(css("#form-details_dates_0_date", value: "2050-10-10"))
  end

  feature "edit not disabled when there's a lead associated to the event", %{
    session: session,
    user: user
  } do
    template = insert(:package_template, user: user)
    event = insert(:booking_event, package_template_id: template.id)
    insert(:lead, user: user, booking_event_id: event.id)

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> scroll_to_bottom()
    |> scroll_into_view(testid("actions"))
    |> click(button("Manage"))
    |> click(button("Edit"))
    |> assert_text("Edit booking event: Details")
  end

  feature "edit hidden when event is disabled", %{
    session: session,
    user: user
  } do
    template = insert(:package_template, user: user)
    insert(:booking_event, package_template_id: template.id, name: "Event 1")

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> scroll_to_bottom()
    |> scroll_into_view(testid("actions"))
    |> click(button("Manage"))
    |> click(button("Disable"))
    |> assert_text("Disable this event?")
    |> click(button("Disable Event"))
    |> assert_flash(:success, text: "Event disabled successfully")
    |> assert_text("Disabled")
    |> click(button("Manage"))
    |> refute_has(button("Edit"))
  end

  feature "edit the event", %{session: session, user: user} do
    %{id: template_id} = template = insert(:package_template, user: user)
    insert(:booking_event, package_template_id: template.id, name: "Event 1")

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> scroll_to_bottom()
    |> scroll_into_view(testid("actions"))
    |> click(button("Manage"))
    |> click(button("Edit"))
    |> assert_text("Edit booking event: Details")
    |> fill_in(text_field("Title"), with: "My modified event")
    |> click(button("Next"))
    |> assert_text("Edit booking event: Select package")
    |> assert_has(checkbox("Include questionnaire in booking event?", selected: true))
    |> click(button("Next"))
    |> assert_text("Edit booking event: Customize")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_flash(:success, text: "Booking event saved successfully")
    |> assert_path("/booking-events")
    |> assert_text("My modified event")

    thumbnail_url = PicselloWeb.Endpoint.static_url() <> "/images/phoenix.png"

    assert [
             %{
               name: "My modified event",
               location: "on_location",
               address: "320 1st St N, Jax Beach, FL",
               duration_minutes: 45,
               buffer_minutes: 15,
               include_questionnaire?: true,
               dates: [
                 %{
                   date: ~D[2050-12-10],
                   time_blocks: [
                     %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]},
                     %{start_time: ~T[15:00:00], end_time: ~T[17:00:00]}
                   ]
                 }
               ],
               package_template_id: ^template_id,
               thumbnail_url: ^thumbnail_url,
               description: "<p>My custom description</p>"
             }
           ] = Picsello.Repo.all(Picsello.BookingEvent)
  end

  feature "edit the event, disable questionnaire", %{session: session, user: user} do
    %{id: template_id} = template = insert(:package_template, user: user)
    insert(:booking_event, package_template_id: template.id, name: "Event 1")

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> scroll_to_bottom()
    |> scroll_into_view(testid("actions"))
    |> click(button("Manage"))
    |> click(button("Edit"))
    |> assert_text("Edit booking event: Details")
    |> fill_in(text_field("Title"), with: "My modified event")
    |> click(button("Next"))
    |> assert_text("Edit booking event: Select package")
    |> click(css("input[name='booking_event[include_questionnaire?]']"))
    |> assert_has(checkbox("Include questionnaire in booking event?", selected: false))
    |> click(button("Next"))
    |> assert_text("Edit booking event: Customize")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_flash(:success, text: "Booking event saved successfully")
    |> assert_path("/booking-events")
    |> assert_text("My modified event")

    thumbnail_url = PicselloWeb.Endpoint.static_url() <> "/images/phoenix.png"

    assert [
             %{
               name: "My modified event",
               location: "on_location",
               address: "320 1st St N, Jax Beach, FL",
               duration_minutes: 45,
               buffer_minutes: 15,
               include_questionnaire?: false,
               dates: [
                 %{
                   date: ~D[2050-12-10],
                   time_blocks: [
                     %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]},
                     %{start_time: ~T[15:00:00], end_time: ~T[17:00:00]}
                   ]
                 }
               ],
               package_template_id: ^template_id,
               thumbnail_url: ^thumbnail_url,
               description: "<p>My custom description</p>"
             }
           ] = Picsello.Repo.all(Picsello.BookingEvent)
  end

  feature "duplicate the event", %{session: session, user: user} do
    %{id: template_id} = insert(:package_template, user: user)

    %{id: old_event_id, thumbnail_url: thumbnail_url} =
      insert(:booking_event, package_template_id: template_id, name: "Event 1")

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> scroll_to_bottom()
    |> scroll_into_view(testid("actions"))
    |> click(testid("actions"))
    |> click(button("Duplicate"))
    |> assert_text("Add booking event: Details")
    |> scroll_into_view(testid("add-date"))
    |> click(css("#form-details_dates_0_date"))
    |> fill_in(css("#form-details_dates_0_date"), with: "10-10-2050")
    |> fill_in(css("#form-details_dates_0_time_blocks_0_start_time"), with: "13:00")
    |> fill_in(css("#form-details_dates_0_time_blocks_0_end_time"), with: "15:00")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Add booking event: Select package")
    |> click(button("Next"))
    |> assert_text("Add booking event: Customize")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_flash(:success, text: "Booking event saved successfully")
    |> assert_path("/booking-events")

    assert [
             %{id: ^old_event_id},
             %{
               name: "Event 1",
               location: "on_location",
               address: "320 1st St N, Jax Beach, FL",
               duration_minutes: 45,
               buffer_minutes: 15,
               dates: [
                 %{
                   date: ~D[2050-10-10],
                   time_blocks: [
                     %{start_time: ~T[13:00:00], end_time: ~T[15:00:00]}
                   ]
                 }
               ],
               package_template_id: ^template_id,
               thumbnail_url: ^thumbnail_url,
               description: "<p>My custom description</p>"
             }
           ] = Picsello.Repo.all(Picsello.BookingEvent |> Ecto.Query.order_by(:inserted_at))
  end

  feature "disable/enable event", %{session: session, user: user} do
    Repo.update_all(Organization, set: [stripe_account_id: "stripe_id"])

    Mox.stub(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)

    template = insert(:package_template, user: user)
    insert(:booking_event, package_template_id: template.id, name: "Event 1")

    session
    |> visit("/calendar")
    |> click(link("Manage booking events"))
    |> scroll_to_bottom()
    |> scroll_into_view(testid("actions"))
    |> click(button("Manage"))
    |> click(button("Disable"))
    |> assert_text("Disable this event?")
    |> click(button("Disable Event"))
    |> assert_flash(:success, text: "Event disabled successfully")
    |> assert_text("Disabled")

    assert [%{status: :disabled}] = Picsello.Repo.all(Picsello.BookingEvent)

    session
    |> click(button("Manage"))
    |> click(button("Enable"))
    |> assert_flash(:success, text: "Event enabled successfully")
    |> click(button("Manage"))
    |> assert_text("Disable")

    assert [%{status: :active}] = Picsello.Repo.all(Picsello.BookingEvent)
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
