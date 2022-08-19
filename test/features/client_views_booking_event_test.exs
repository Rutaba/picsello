defmodule Picsello.ClientViewsBookingEventTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup do
    user =
      insert(:user,
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos"
        }
      )
      |> onboard!

    template =
      insert(:package_template,
        user: user,
        job_type: "mini",
        name: "My custom package",
        download_count: 3
      )

    event =
      insert(:booking_event,
        name: "Event 1",
        package_template_id: template.id,
        duration_minutes: 45,
        location: "studio",
        address: "320 1st St N",
        description: "This is the description",
        dates: [
          %{
            date: ~D[2050-12-10],
            time_blocks: [
              %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]}
            ]
          },
          %{
            date: ~D[2050-12-11],
            time_blocks: [
              %{start_time: ~T[11:00:00], end_time: ~T[13:00:00]},
              %{start_time: ~T[16:00:00], end_time: ~T[17:00:00]}
            ]
          }
        ]
      )

    [
      photographer: user,
      booking_event_url:
        Routes.client_booking_event_path(
          PicselloWeb.Endpoint,
          :show,
          user.organization.slug,
          event.id
        )
    ]
  end

  feature "client views event page", %{session: session, booking_event_url: booking_event_url} do
    session
    |> visit(booking_event_url)
    |> assert_text("Mary Jane Photography")
    |> assert_has(css("h1", text: "Event 1"))
    |> assert_text("3 images include | 45 min session | In Studio")
    |> assert_text("Dec 10, 2050")
    |> assert_text("320 1st St N")
    |> assert_text("This is the description")
    |> assert_has(css("img[src$='/phoenix.png']"))
  end

  feature "client books event", %{session: session, booking_event_url: booking_event_url} do
    session
    |> visit(booking_event_url)
    |> click(link("Book now"))
    |> fill_in(text_field("Your name"), with: " ")
    |> fill_in(text_field("Your email"), with: " ")
    |> fill_in(text_field("Your phone number"), with: " ")
    |> assert_text("Your name can't be blank")
    |> assert_text("Your email can't be blank")
    |> assert_text("Your phone number is invalid")
    |> fill_in(text_field("Your name"), with: "Chad Smith")
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your phone number"), with: "987 123 4567")
    |> assert_text("December 2050")
    |> click(button("previous month"))
    |> assert_text("November 2050")
    |> click(button("next month"))
    |> assert_text("December 2050")
    |> assert_value(css("input:checked[name='booking[date]']", visible: false), "2050-12-10")
    |> assert_inner_text(
      testid("time_picker"),
      "Saturday, December 10 9:00am 10:00am 11:00am 12:00pm"
    )
    |> click(css("#date_picker-wrapper label", text: "11"))
    |> assert_value(css("input:checked[name='booking[date]']", visible: false), "2050-12-11")
    |> assert_inner_text(
      testid("time_picker"),
      "Sunday, December 11 11:00am 12:00pm 4:00pm"
    )
    |> assert_disabled_submit(text: "Next")
    |> click(css("label", text: "11:00am"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text(
      "Your session will not be considered officially booked until the contract is signed and a retainer is paid"
    )
  end

  feature "client tries to book unavailable time", %{
    session: session,
    booking_event_url: booking_event_url,
    photographer: photographer
  } do
    session
    |> visit(booking_event_url)
    |> click(link("Book now"))
    |> fill_in(text_field("Your name"), with: "Chad Smith")
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your phone number"), with: "987 123 4567")
    |> click(css("label", text: "11:00am"))
    |> wait_for_enabled_submit_button(text: "Next")

    job = insert(:lead, %{user: photographer})

    insert(:shoot,
      job: job,
      starts_at: DateTime.new!(~D[2050-12-10], ~T[11:00:00], photographer.time_zone)
    )

    session
    |> click(button("Next"))
    |> assert_flash(:error, text: "This time is not available anymore")
  end
end
