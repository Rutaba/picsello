defmodule Picsello.ClientVisitsPhotographerProfileTest do
  use Picsello.FeatureCase, async: true

  setup do
    user =
      insert(:user,
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos"
        },
        onboarding: %{
          color: "3376FF",
          job_types: ~w(portrait event),
          website: "http://photos.example.com"
        }
      )

    [
      photographer: user,
      profile_url: Routes.profile_path(PicselloWeb.Endpoint, :index, user.organization.slug)
    ]
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

  feature "contact", %{session: session, profile_url: profile_url} do
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
  end
end
