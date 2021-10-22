defmodule Picsello.EditLeadPackageTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    lead =
      insert(:lead, %{
        user: user,
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 2,
          base_price: 100
        },
        shoots: [%{}, %{}]
      })

    [lead: lead, session: session]
  end

  feature "user edits a package", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Edit package"))
    |> assert_has(button("Cancel"))
    |> assert_value(
      select("package[package_template_id]"),
      lead.package.package_template_id |> inspect
    )
    |> assert_value(text_field("Package price"), "$1.00")
    |> assert_value(text_field("Package name"), "My Package")
    |> assert_value(text_field("Package description"), "My custom description")
    |> assert_value(select("Number of shoots for this package"), "2")
    |> assert_has(css("option[disabled]", text: "1"))
    |> fill_in(text_field("Package price"), with: "")
    |> assert_has(css("label", text: "Package price can't be blank"))
    |> fill_in(text_field("Package price"), with: "2.00")
    |> fill_in(text_field("Package name"), with: "My Greatest Package")
    |> fill_in(text_field("Package description"), with: "indescribably great.")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(button("Edit package"))
    |> assert_value(text_field("Package price"), "$2.00")
    |> assert_value(text_field("Package name"), "My Greatest Package")
    |> assert_value(text_field("Package description"), "indescribably great.")
  end

  feature "user changes package template", %{session: session, user: user, lead: lead} do
    template = insert(:package, %{user: user, name: "Other Template"})

    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Edit package"))
    |> click(css("option", text: "Other Template"))
    |> assert_value(text_field("Package name"), "Other Template")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(button("Edit package"))
    |> assert_value(select("package[package_template_id]"), template.id |> inspect)
  end
end
