defmodule Picsello.ClientVisitsPhotographerProfileTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Job, Repo, Onboardings}
  require Ecto.Query

  setup do
    user =
      insert(:user,
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos",
          profile: %{
            color: Picsello.Profiles.Profile.colors() |> hd,
            job_types: ~w(portrait event)
          }
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
      job_type: "portrait",
      base_price: 3000
    )

    insert(:package_template,
      name: "Silver",
      description: "<br/><p>silver</p><br/><p>desc</p>",
      download_count: 1,
      user: user,
      job_type: "event",
      base_price: 2000
    )

    [
      photographer: user,
      profile_url: Routes.profile_path(PicselloWeb.Endpoint, :index, user.organization.slug)
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
    |> assert_has(testid("job-type", text: "Portrait"))
    |> assert_has(testid("job-type", text: "Event"))
    |> assert_has(radio_button("Portrait", visible: false))
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
    |> click(css("label", text: "Portrait"))
    |> fill_in(text_field("Your message"), with: "May you take some pictures of our family?")
    |> wait_for_enabled_submit_button()
    |> click(button("Submit"))
    |> assert_text("Message sent")
    |> assert_text("We'll contact you soon!")

    assert %{
             type: "portrait",
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
                 job type: Portrait
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
end
