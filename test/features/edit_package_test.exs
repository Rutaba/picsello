defmodule Picsello.EditPackageTest do
  use Picsello.FeatureCase, async: true

  setup :authenticated

  setup %{session: session, user: user} do
    job =
      insert(:job, %{
        user: user,
        package: %{
          name: "My Package Template",
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
    |> visit("/jobs/#{job.id}")
    |> click(link("Edit package"))
    |> assert_has(link("Cancel edit package"))
    |> assert_value(text_field("Package price"), "$1.00")
    |> assert_value(text_field("Package name"), "My Package Template")
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
    |> assert_has(definition("Package price", text: "$2.00"))
    |> assert_has(definition("Package name", text: "My Greatest Package"))
    |> assert_has(definition("Package description", text: "indescribably great."))
  end
end
