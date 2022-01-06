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
            color: "3376FF",
            job_types: ~w(portrait event),
            website: "http://photos.example.com"
          }
        }
      )
      |> onboard!

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
    |> assert_text("What we offer:")
    |> assert_text("Portrait")
    |> assert_text("Event")
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
    |> assert_text("Not Found")
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
    |> click(button("Submit"))
    |> assert_text("Your name can't be blank")
    |> assert_text("Your email can't be blank")
    |> assert_text("Your phone number can't be blank")
    |> assert_text("What photography type are you interested in? can't be blank")
    |> assert_text("Your message can't be blank")
    |> fill_in(text_field("Your name"), with: "Chad Smith")
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your phone number"), with: "987 123 4567")
    |> click(css("label", text: "Portrait"))
    |> fill_in(text_field("Your message"), with: "May you take some pictures of our family?")
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

    session
    |> visit(profile_url)
    |> fill_in(text_field("Your email"), with: "chad@example.com")
    |> fill_in(text_field("Your name"), with: "Not Chad")
    |> fill_in(text_field("Your phone number"), with: "918 123 4567")
    |> click(css("label", text: "Event"))
    |> fill_in(text_field("Your message"), with: "May you take some pictures of our party?")
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
end
