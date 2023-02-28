defmodule Picsello.ClientViewsBookingEventTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils
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
        download_count: 3,
        base_price: ~M[1500]USD
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

  feature "when event is disabled", %{session: session, booking_event_url: booking_event_url} do
    Picsello.Repo.update_all(Picsello.BookingEvent,
      set: [status: "disabled"]
    )

    session
    |> visit(booking_event_url)
    |> assert_text("No available times")
  end
end
