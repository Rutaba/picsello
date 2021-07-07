defmodule Picsello.CreateLeadPackageTest do
  use Picsello.FeatureCase, async: true

  import Picsello.JobFixtures

  setup :authenticated

  feature "user sees validation errors when creating a package", %{session: session, user: user} do
    job = fixture(:job, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/jobs/#{job.id}/packages/new")
    |> assert_has(css("h2", text: "Elizabeth Taylor Wedding"))
    |> fill_in(text_field("Package name"), with: " ")
    |> fill_in(text_field("Package description"), with: " ")
    |> fill_in(text_field("Package price"), with: "-1")
    |> assert_has(css("label", text: "Package name can't be blank"))
    |> assert_has(css("label", text: "Package description can't be blank"))
    |> assert_has(css("label", text: "Package price must be greater than or equal to 0"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user selects previous package as template to job creation", %{
    session: session,
    user: user
  } do
    fixture(:package, %{
      price: 100,
      name: "My Package Template",
      description: "My custom description",
      shoot_count: 2,
      user: user
    })

    job =
      fixture(:job, %{
        client: %{
          email: "taylor@example.com",
          name: "Elizabeth Taylor"
        },
        type: "wedding",
        user: user
      })

    session
    |> visit("/jobs/#{job.id}/packages/new")
    |> assert_has(
      css("select[name='package[package_template_id]'] option:checked",
        text: "Select below"
      )
    )
    |> click(option("My Package Template"))
    |> assert_value(text_field("Package description"), "My custom description")
    |> assert_value(text_field("Package name"), "My Package Template")
    |> assert_value(text_field("Package price"), "$1.00")
    |> assert_value(select("Number of shoots for job"), "2")
    |> fill_in(text_field("Package name"), with: "My job package")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(definition("Client", text: "Elizabeth Taylor"))
    |> assert_has(definition("Client email", text: "taylor@example.com"))
    |> assert_has(definition("Package description", text: "My custom description"))
    |> assert_has(definition("Package name", text: "My job package"))
    |> assert_has(definition("Package price", text: "$1.00"))
  end

  feature "user is redirected to new package page when job is not associated to package", %{
    session: session,
    user: user
  } do
    job = fixture(:job, %{user: user})

    session
    |> visit("/jobs/#{job.id}")
    |> assert_path("/jobs/#{job.id}/packages/new")
  end

  feature "user is redirected to job show page when job is already associated to package", %{
    session: session,
    user: user
  } do
    job = fixture(:job, %{package: %{}, user: user})

    session
    |> visit("/jobs/#{job.id}/packages/new")
    |> assert_path("/jobs/#{job.id}")
  end
end
