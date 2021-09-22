defmodule Picsello.EditLeadPackageTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    job =
      insert(:job, %{
        user: user,
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 2,
          price: 100
        },
        shoots: [%{}, %{}]
      })

    [job: job, session: session]
  end

  feature "user edits a package", %{session: session, job: job} do
    session
    |> visit("/leads/#{job.id}")
    |> click(button("Edit package"))
    |> assert_has(button("Cancel"))
    |> assert_value(
      select("package[package_template_id]"),
      job.package.package_template_id |> inspect
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

  feature "user adds package template", %{session: session, job: job} do
    session
    |> visit("/leads/#{job.id}")
    |> click(button("Edit package"))
    |> click(css("option", text: "+ New Package"))
    |> assert_has(css("option", selected: true, text: "+ New Package"))
    |> fill_in(text_field("Package price"), with: "3.00")
    |> wait_for_enabled_submit_button()
    |> assert_has(css("option", selected: true, text: "+ New Package"))
    |> click(button("Save"))
    |> click(button("Edit package"))
    |> assert_has(css("option", text: job.package.name))
  end

  feature "user changes package template", %{session: session, user: user, job: job} do
    template = insert(:package, %{user: user, name: "Other Template"})

    session
    |> visit("/leads/#{job.id}")
    |> click(button("Edit package"))
    |> click(css("option", text: "Other Template"))
    |> assert_value(text_field("Package name"), "Other Template")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(button("Edit package"))
    |> assert_value(select("package[package_template_id]"), template.id |> inspect)
  end
end
