defmodule Picsello.UserEditsPublicProfileTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup do
    user =
      insert(:user,
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos",
          profile: %{
            color: "#3376FF",
            job_types: ~w(portrait event),
            website: "http://photos.example.com"
          }
        }
      )
      |> onboard!

    [
      user: user
    ]
  end

  setup :authenticated

  feature "clicks to customize profile", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Public Profile"))
    |> click(button("Customize Profile"))
    |> assert_path(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("Mary Jane Photography")
    |> assert_text("What we offer:")
    |> assert_text("Portrait")
    |> assert_text("Event")
    |> assert_has(radio_button("Portrait", visible: false))
    |> assert_has(radio_button("Event", visible: false))
    |> assert_has(link("See our full portfolio"))
    |> assert_has(css("a[href*='/photographer/mary-jane-photos']", text: "View"))
    |> click(button("Close"))
    |> assert_path(Routes.profile_settings_path(PicselloWeb.Endpoint, :index))
  end

  feature "user edits color", %{session: session} do
    session
    |> assert_has(link("Settings"))
    |> visit(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("What we offer:")
    |> assert_has(css("svg[style*='color: #3376FF']", count: 2))
    |> click(button("Change color"))
    |> within_modal(&click(&1, css("li.aspect-h-1.aspect-w-1:nth-child(3)")))
    |> click(button("Save"))
    |> assert_has(css("svg[style*='color: #3376FF']", count: 0))
    |> assert_has(css("svg[style*='color: #3AE7C7']", count: 2))
  end
end
