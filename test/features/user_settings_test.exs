defmodule Picsello.UserSettingsTest do
  @moduledoc false
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

    insert(:brand_link, user: user)

    [
      user: user
    ]
  end

  setup :authenticated

  feature "updates business name", %{session: session, user: user} do
    session
    |> click(testid("subnav-Settings"))
    |> click(link("Account"))
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
    |> click(testid("subnav-Settings"))
    |> click(link("Account"))
    |> assert_value(select("Timezone"), "America/Sao_Paulo")
    |> find(select("Timezone"), &click(&1, option("(GMT-05:00) America/New_York")))
    |> click(button("Change timezone"))
    |> assert_flash(:success, text: "Timezone changed successfully")

    user = user |> Repo.reload()

    assert %{
             time_zone: "America/New_York"
           } = user
  end

  feature "updates phone number", %{session: session, user: user} do
    session
    |> click(testid("subnav-Settings"))
    |> click(link("Account"))
    |> fill_in(text_field("Phone number"), with: "")
    |> assert_text("Phone number can't be blank")
    |> fill_in(text_field("Phone number"), with: "(222) 222-2222")
    |> wait_for_enabled_submit_button(text: "Change number")
    |> click(button("Change number"))
    |> assert_flash(:success, text: "Phone number updated successfully")

    user = user |> Repo.reload()

    assert %{
             onboarding: %{phone: "(222) 222-2222"}
           } = user
  end

  feature "enables offline payments", %{session: session, user: user} do
    session
    |> click(testid("subnav-Settings"))
    |> click(link("Finances"))
    |> scroll_to_bottom()
    |> assert_has(css("h3", text: "Via Stripe Online"))
    |> assert_has(css("label", text: "Disabled", count: 5))
    |> assert_has(css("h3", text: "Via Manual Methods"))
    |> click(css("label", text: "Disabled", count: 5, at: 4))

    organization = user.organization |> Repo.reload()
    assert %{payment_options: %{allow_cash: true}} = organization
  end
end
