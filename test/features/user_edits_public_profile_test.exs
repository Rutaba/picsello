defmodule Picsello.UserEditsPublicProfileTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup do
    color = Picsello.Profiles.Profile.colors() |> hd

    user =
      insert(:user,
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos",
          profile: %{
            color: color,
            job_types: ~w(portrait event),
            website: "photos.example.com"
          }
        }
      )
      |> onboard!

    insert(:package_template, user: user, job_type: "portrait", base_price: 3000)
    insert(:package_template, user: user, job_type: "portrait", base_price: 2000)

    [
      user: user,
      color: color
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
    |> assert_has(definition("Portrait", text: "Starting at $20"))
    |> assert_text("Event")
    |> assert_has(radio_button("Portrait", visible: false))
    |> assert_has(radio_button("Event", visible: false))
    |> assert_has(link("See our full portfolio"))
    |> assert_has(css("a[href*='/photographer/mary-jane-photos']", text: "View"))
    |> click(button("Close"))
    |> assert_path(Routes.profile_settings_path(PicselloWeb.Endpoint, :index))
  end

  feature "user edits color", %{session: session, color: color} do
    session
    |> assert_has(link("Settings"))
    |> visit(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("What we offer:")
    |> assert_has(css("svg[style*='color: #{color}']", count: 2))
    |> click(button("Change color"))
    |> within_modal(&click(&1, css("li.aspect-h-1.aspect-w-1:nth-child(3)")))
    |> click(button("Save"))
    |> assert_has(css("svg[style*='color: #{color}']", count: 0))
    |> assert_has(
      css("svg[style*='color: #{Picsello.Profiles.Profile.colors() |> Enum.at(2)}']", count: 2)
    )
  end

  feature "user edits job types", %{session: session} do
    session
    |> assert_has(link("Settings"))
    |> visit(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("What we offer:")
    |> assert_has(testid("job-type", count: 2))
    |> assert_has(testid("job-type", text: "Portrait"))
    |> assert_has(testid("job-type", text: "Event"))
    |> click(button("Edit Photography Types"))
    |> within_modal(&click(&1, css("label", text: "Event")))
    |> within_modal(&click(&1, css("label", text: "Family")))
    |> click(button("Save"))
    |> assert_has(testid("job-type", count: 2))
    |> assert_has(testid("job-type", text: "Portrait"))
    |> assert_has(testid("job-type", text: "Family"))
  end

  feature "user edits website", %{session: session} do
    session
    |> assert_has(link("Settings"))
    |> visit(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("What we offer:")
    |> assert_has(css("a[href='https://photos.example.com']", text: "See our full portfolio"))
    |> resize_window(1280, 900)
    |> click(button("Edit Link"))
    |> fill_in(text_field("organization_profile_website"), with: "http://google.com")
    |> click(button("Save"))
    |> assert_has(css("a[href='http://google.com']", text: "See our full portfolio"))
    |> click(button("Edit Link"))
    |> click(checkbox("I don't have one"))
    |> click(button("Save"))
    |> assert_has(css("a[href='#']", text: "See our full portfolio"))
  end

  feature "user edits description", %{session: session} do
    session
    |> assert_has(link("Settings"))
    |> visit(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("What we offer:")
    |> click(button("Edit Description"))
    |> click(css("div.ql-editor[data-placeholder='Start typing…']"))
    |> send_keys(["my description"])
    |> click(button("Save"))
    |> assert_has(testid("description", text: "my description"))
  end
end
