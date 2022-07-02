defmodule Picsello.UserSettingsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query
  alias Picsello.{Repo}

  setup do
    user =
      insert(:user,
        time_zone: "America/Sao_Paulo",
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos"
        }
      )
      |> onboard!

    insert(:brand_link, user: user, link: nil)
    [
      user: user
    ]
  end

  setup :authenticated

  feature "updates business name", %{session: session, user: user} do
    session
    |> click(link("Settings"))
    |> assert_value(text_field("Business name"), "Mary Jane Photography")
    |> fill_in(text_field("Business name"), with: " ")
    |> assert_text("Business name can't be blank")
    |> fill_in(text_field("Business name"), with: "MJ Photography")
    |> wait_for_enabled_submit_button(text: "Change name")
    |> click(button("Change name"))
    |> within_modal(&click(&1, button("Yes, change name")))
    |> assert_flash(:success, text: "Business name changed successfully")

    organization = user |> Repo.reload() |> Repo.preload(:organization) |> Map.get(:organization)

    assert %{
             name: "MJ Photography",
             slug: "mj-photography",
             previous_slug: "mary-jane-photos"
           } = organization

    session
    |> visit("/photographer/mary-jane-photos")
    |> assert_text("SPECIALIZING IN")
    |> assert_path("/photographer/mj-photography")
  end

  feature "updates timezone", %{session: session, user: user} do
    session
    |> click(link("Settings"))
    |> assert_value(select("Timezone"), "America/Sao_Paulo")
    |> find(select("Timezone"), &click(&1, option("(GMT-05:00) America/New_York")))
    |> click(button("Change timezone"))
    |> assert_flash(:success, text: "Timezone changed successfully")

    user = user |> Repo.reload()

    assert %{
             time_zone: "America/New_York"
           } = user
  end
end
