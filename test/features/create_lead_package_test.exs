defmodule Picsello.CreateLeadPackageTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  feature "user sees validation errors when creating a package", %{session: session, user: user} do
    job = insert(:job, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/leads/#{job.id}")
    |> click(button("Add a package"))
    |> fill_in(text_field("Package name"), with: " ")
    |> fill_in(text_field("Package description"), with: " ")
    |> fill_in(text_field("Package price"), with: "-1")
    |> assert_has(css("label", text: "Package name can't be blank"))
    |> assert_has(css("label", text: "Package description can't be blank"))
    |> assert_has(css("label", text: "Package price must be greater than or equal to 0"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> assert_has(
      css("select[name='package[package_template_id]'] option:checked", text: "+ New Package")
    )
    |> find(select("Number of shoots for this package"), &click(&1, option("2")))
    |> fill_in(text_field("Package name"), with: "Wedding Deluxe")
    |> fill_in(text_field("Package description"), with: "My greatest wedding package")
    |> fill_in(text_field("Package price"), with: "1234.50")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(button("Add shoot details", count: 2))
    |> click(button("Edit package"))
    |> assert_has(option("Wedding Deluxe"))
    |> assert_value(text_field("Package description"), "My greatest wedding package")
    |> assert_value(text_field("Package name"), "Wedding Deluxe")
    |> assert_value(text_field("Package price"), "$1,234.50")
    |> click(button("Cancel"))
    |> assert_has(button("Add shoot details", count: 2))
    |> assert_has(link("Finish shoot details", count: 1))
  end

  feature "user selects previous package as template to job creation", %{
    session: session,
    user: user
  } do
    insert(:package, %{
      price: 100,
      name: "My Package Template",
      description: "My custom description",
      shoot_count: 2,
      user: user
    })

    job =
      insert(:job, %{
        client: %{
          email: "taylor@example.com",
          name: "Elizabeth Taylor"
        },
        type: "wedding",
        user: user
      })

    session
    |> visit("/leads/#{job.id}")
    |> click(button("Add a package"))
    |> assert_has(
      css("select[name='package[package_template_id]'] option:checked",
        text: "Select below"
      )
    )
    |> click(option("My Package Template"))
    |> assert_value(text_field("Package description"), "My custom description")
    |> assert_value(text_field("Package name"), "My Package Template")
    |> assert_value(text_field("Package price"), "$1.00")
    |> assert_value(select("Number of shoots for this package"), "2")
    |> fill_in(text_field("Package name"), with: "My job package")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(button("Edit package"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_value(text_field("Package description"), "My custom description")
    |> assert_value(text_field("Package name"), "My job package")
    |> assert_value(text_field("Package price"), "$1.00")
  end
end
