defmodule Picsello.UserEditsPublicProfileTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup do
    color = Picsello.Profiles.Profile.colors() |> hd

    user =
      insert(:user,
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos"
        }
      )
      |> onboard!

    insert(:brand_link, user: user)
    insert(:package_template, user: user, job_type: "portrait", base_price: 3000)
    insert(:package_template, user: user, job_type: "portrait", base_price: 2000)

    [
      user: user,
      color: color
    ]
  end

  setup :authenticated

  feature "clicks to customize profile", %{session: session, user: %{organization: organization}} do
    session
    |> click(testid("subnav-Settings"))
    |> click(link("Public Profile"))
    |> click(button("Customize Profile"))
    |> assert_path(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("Mary Jane Photography")
    |> assert_text("About #{organization.name}.")
    |> assert_text("SPECIALIZING IN")
    |> assert_text("Wedding")
    |> assert_text("Event")
    |> assert_has(radio_button("Wedding", visible: false))
    |> assert_has(radio_button("Event", visible: false))
    |> assert_has(link("See our full portfolio"))
    |> assert_has(css("a[href*='/photographer/mary-jane-photos']", text: "View"))
    |> click(button("Close"))
    |> assert_path(Routes.profile_settings_path(PicselloWeb.Endpoint, :index))
  end

  feature "user edits website", %{session: session, user: %{organization: organization}} do
    session
    |> assert_has(testid("subnav-Settings"))
    |> visit(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("About #{organization.name}.")
    |> assert_text("SPECIALIZING IN")
    |> assert_has(css("a[href='https://photos.example.com']", text: "See our full portfolio"))
    |> resize_window(1280, 900)
    |> scroll_into_view(testid("edit-link-button"))
    |> click(button("Edit Link"))
    |> fill_in(text_field("organization_brand_links_0_link"), with: "http://google.com")
    |> click(button("Save"))
    |> assert_has(css("a[href='http://google.com']", text: "See our full portfolio"))
    |> click(button("Edit Link"))
    |> fill_in(text_field("organization_brand_links_0_link"), with: "")
    |> click(button("Save"))
    |> assert_has(css("a", text: "See our full portfolio"))
  end

  feature "user edits description", %{session: session, user: %{organization: organization}} do
    session
    |> assert_has(testid("subnav-Settings"))
    |> visit(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("About #{organization.name}.")
    |> assert_text("SPECIALIZING IN")
    |> scroll_into_view(testid("edit-description-button"))
    |> click(testid("edit-description-button"))
    |> assert_has(css("div.ql-editor[data-placeholder='Start typing…']"))
    |> fill_in_quill("my description")
    |> click(button("Save"))
    |> assert_has(testid("description", text: "my description"))
  end

  feature "user edits job types description", %{
    session: session,
    user: %{organization: organization}
  } do
    session
    |> assert_has(testid("subnav-Settings"))
    |> visit(Routes.profile_settings_path(PicselloWeb.Endpoint, :edit))
    |> assert_text("About #{organization.name}.")
    |> assert_text("SPECIALIZING IN")
    |> scroll_into_view(testid("edit-description-button"))
    |> click(testid("edit-description-button"))
    |> assert_has(css("div.ql-editor[data-placeholder='Start typing…']"))
    |> fill_in_quill("my description")
    |> click(button("Save"))
    |> assert_has(testid("description", text: "my description"))
  end
end
