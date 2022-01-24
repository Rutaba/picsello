defmodule Picsello.UserSettingsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query
  alias Picsello.{Repo}

  setup do
    user =
      insert(:user,
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos"
        }
      )
      |> onboard!

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
    |> assert_flash(:success, text: "Business name changed successfully")

    organization = user |> Repo.preload(:organization, force: true) |> Map.get(:organization)

    assert %{
             name: "MJ Photography",
             slug: "mj-photography",
             previous_slug: "mary-jane-photos"
           } = organization

    session
    |> visit("/photographer/mary-jane-photos")
    |> assert_text("What we offer")
    |> assert_path("/photographer/mj-photography")
  end
end
