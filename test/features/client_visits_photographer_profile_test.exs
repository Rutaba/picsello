defmodule Picsello.ClientVisitsPhotographerProfileTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils
  alias Picsello.{Job, Repo, Onboardings}
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

    insert(:brand_link, user: user, link: "http://photos.example.com", active?: true)

    insert(:brand_link,
      user: user,
      link: "http://photos.example1.com",
      show_on_profile?: true,
      active?: true
    )

    insert(:package_template,
      name: "Gold",
      description: "gold desc",
      download_count: 2,
      user: user,
      job_type: "wedding",
      base_price: ~M[3000]USD
    )

    insert(:package_template,
      name: "Silver",
      description: "<br/><p>silver</p><br/><p>desc</p>",
      download_count: 1,
      user: user,
      job_type: "event",
      base_price: ~M[2000]USD
    )

    template =
      insert(:package_template,
        user: user,
        job_type: "mini",
        name: "My custom package",
        download_count: 3,
        base_price: ~M[1500]USD
      )

    [
      photographer: user |> Repo.preload(organization: :organization_job_types),
      profile_url: Routes.profile_path(PicselloWeb.Endpoint, :index, user.organization.slug),
      booking_package_id: template.id
    ]
  end

  def latest_job(user) do
    user
    |> Job.for_user()
    |> Ecto.Query.order_by(desc: :id)
    |> Ecto.Query.limit(1)
    |> Repo.one()
    |> Repo.preload([:client, :client_messages])
  end

  feature "check it out", %{session: session, profile_url: profile_url} do
    session
    |> visit(profile_url)
    |> assert_text("Mary Jane Photography")
    |> assert_text("SPECIALIZING IN:")
    |> assert_has(testid("job-type", text: "Wedding"))
    |> assert_has(testid("job-type", text: "Event"))
    |> assert_has(radio_button("Wedding", visible: false))
    |> assert_has(radio_button("Event", visible: false))
    |> assert_has(link("See our full portfolio"))
  end

  feature "404", %{session: session, photographer: user, profile_url: profile_url} do
    session
    |> sign_in(user)
    |> click(link("Settings"))
    |> click(link("Public Profile"))
    |> assert_has(testid("url", text: profile_url))
    |> click(css("label", text: "Enabled"))
    |> assert_has(css("label", text: "Disabled"))

    refute user.organization |> Repo.reload!() |> Picsello.Profiles.enabled?()

    session
    |> visit(session |> find(testid("url")) |> Element.text())
    |> assert_has(testid("404-page", text: "Whoops! We lost that page in our camera bag."))
  end

  feature "404 when subscription is expired", %{
    session: session,
    photographer: user,
    profile_url: profile_url
  } do
    plan = insert(:subscription_plan)
    insert(:subscription_event, user: user, subscription_plan: plan, status: "canceled")

    session
    |> visit(profile_url)
    |> assert_text("Whoops! We lost that page in our camera bag")
  end

  feature "selects job type if there is only one", %{
    photographer: photographer,
    session: session,
    profile_url: profile_url
  } do
    photographer
    |> Onboardings.changeset(%{
      onboarding: %{job_types: [:event]}
    })
    |> Repo.update()

    session
    |> visit(profile_url)
    |> assert_has(radio_button("Event", visible: false, checked: true))
  end

  feature "contact", %{session: session, profile_url: profile_url, photographer: photographer} do
    session
    |> visit(profile_url)
    |> assert_disabled_submit()
    |> fill_in(text_field("Your name"), with: " ")
    |> fill_in(text_field("Your email"), with: " ")
    |> fill_in(text_field("Your phone number"), with: " ")
    |> fill_in(text_field("Your message"), with: " ")
    |> assert_text("Your name can't be blank")
    |> assert_text("Your email can't be blank")
    |> assert_text("Your phone number is invalid")
    |> assert_text("Your message can't be blank")
    |> fill_in(text_field("Your name"), with: "Chad Smith")
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your phone number"), with: "987 123 4567")
    |> click(css("label", text: "Wedding"))
    |> fill_in(text_field("Your message"), with: "May you take some pictures of our family?")
    |> wait_for_enabled_submit_button()
    |> click(button("Submit"))
    |> assert_text("Message sent")
    |> assert_text("We'll contact you soon!")

    assert %{
             type: "wedding",
             client: %{
               name: "Chad Smith",
               email: "chad@example.com",
               phone: "(987) 123-4567",
               id: client_id
             },
             client_messages: [
               %{
                 body_text: """
                     name: Chad Smith
                    email: chad@example.com
                    phone: (987) 123-4567
                 job type: Wedding
                  message: May you take some pictures of our family?
                 """
               }
             ]
           } = photographer |> latest_job()

    assert_receive {:delivered_email, email}
    %{"subject" => subject, "body" => body} = email |> email_substitutions
    assert "You have a new lead from Chad Smith" = subject
    assert body =~ "Email: chad@example.com"

    session
    |> visit(profile_url)
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your name"), with: "Not Chad")
    |> fill_in(text_field("Your phone number"), with: "918 123 4567")
    |> click(css("label", text: "Event"))
    |> fill_in(text_field("Your message"), with: "May you take some pictures of our party?")
    |> wait_for_enabled_submit_button()
    |> click(button("Submit"))
    |> assert_text("Message sent")

    assert %{
             type: "event",
             client: %{
               name: "Chad Smith",
               email: "chad@example.com",
               phone: "(987) 123-4567",
               id: ^client_id
             },
             client_messages: [
               %{
                 body_text: """
                     name: Not Chad
                    email: chad@example.com
                    phone: (918) 123-4567
                 job type: Event
                  message: May you take some pictures of our party?
                 """
               }
             ]
           } = photographer |> latest_job()
  end

  feature "checks pricing", %{session: session, profile_url: profile_url} do
    session
    |> visit(profile_url)
    |> scroll_into_view(testid("package-detail"))
    |> assert_inner_text(testid("package-detail", count: 2, at: 0), "Silver$20 silver desc")
    |> assert_inner_text(testid("package-detail", count: 2, at: 1), "Gold$30gold desc")
  end

  feature "brand links show on public profile", %{session: session, profile_url: profile_url} do
    session
    |> visit(profile_url)
    |> assert_has(testid("marketing-links", count: 1))
    |> find(css("[data-testid='marketing-links']:first-child"), fn card ->
      card
      |> assert_has(css("a[href='http://photos.example1.com']"))
    end)
  end

  feature "sees no booking events on public profile", %{
    session: session,
    profile_url: profile_url
  } do
    session
    |> visit(profile_url)

    assert false ==
             session
             |> visible?(testid("events-heading"))
  end

  feature "sees only enabled booking events on public profile", %{
    session: session,
    photographer: photographer,
    profile_url: profile_url,
    booking_package_id: booking_package_id
  } do
    event =
      insert(:booking_event,
        name: "Event 1",
        package_template_id: booking_package_id,
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

    insert(:booking_event,
      name: "Event 2",
      package_template_id: booking_package_id,
      duration_minutes: 45,
      location: "studio",
      address: "820 2nd St N",
      description: "This is the description",
      disabled_at: DateTime.utc_now() |> DateTime.truncate(:second),
      dates: [
        %{
          date: ~D[2040-11-10],
          time_blocks: [
            %{start_time: ~T[09:00:00], end_time: ~T[13:00:00]}
          ]
        },
        %{
          date: ~D[2040-11-11],
          time_blocks: [
            %{start_time: ~T[11:00:00], end_time: ~T[13:00:00]},
            %{start_time: ~T[16:00:00], end_time: ~T[17:00:00]}
          ]
        }
      ]
    )

    booking_event_url_enabled =
      Routes.client_booking_event_path(
        PicselloWeb.Endpoint,
        :show,
        photographer.organization.slug,
        event.id
      )

    session
    |> visit(profile_url)
    |> assert_text("Book a session with me!")
    |> find(
      testid("booking-cards", at: 0, count: 1),
      fn booking_card ->
        booking_card
        |> assert_text("Event 1")
        |> assert_text("3 images include | 45 min session | In Studio")
        |> assert_text("Dec 10, 2050")
        |> assert_text("320 1st St N")
        |> assert_text("This is the description")
        |> assert_has(css("img[src$='/phoenix.png']"))
      end
    )
    |> click(link("Book now"))
    |> assert_url_contains(booking_event_url_enabled)
    |> assert_text("Booking with Mary Jane Photography")
  end
end
