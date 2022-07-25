defmodule Picsello.UserCopiesLeadEmbedTest do
  use Picsello.FeatureCase, async: true

  setup do
    color = Picsello.Profiles.Profile.colors() |> hd

    user = %{
      user:
        insert(:user,
          organization: %{
            name: "Mary Jane Photography",
            slug: "mary-jane-photos",
            profile: %{
              color: color,
              job_types: ~w(portrait event)
            }
          }
        )
        |> onboard!
    }

    insert(:brand_link, user)

    user
  end

  setup :authenticated

  feature "clicks to open modal, sees iframe, and copies code", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Public Profile"))
    |> click(button("Preview form"))
    |> assert_text("Tips & Tricks")
    |> assert_text("<iframe src=")
    |> focus_frame(css(".modal-container iframe"))
    |> assert_text("Get in touch")
    |> focus_parent_frame()
    |> click(button("Copy & Close"))
    |> assert_text("Public Profile")
  end
end
