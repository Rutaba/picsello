defmodule Picsello.CreateJobTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Client, Repo, Job, Package}

  setup :authenticated

  feature "user creates job", %{session: session} do
    client_email = "taylor@example.com"
    client_name = "Elizabeth Taylor"

    session
    |> click(link("Create a Job"))
    |> fill_in(text_field("Client name"), with: client_name)
    |> fill_in(text_field("Client email"), with: client_email)
    |> click(option("Wedding"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h2", text: "Elizabeth Taylor Wedding"))
    |> assert_has(css("h1", text: "Add Package"))
    |> assert_has(
      css("select[name='package[package_template_id]'] option:checked", text: "+ New Package")
    )
    |> fill_in(text_field("Package name"), with: "Wedding Deluxe")
    |> fill_in(text_field("Package description"), with: "My greatest wedding package")
    |> fill_in(text_field("Package price"), with: "1234.50")
    |> click(css("option", text: "2"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(definition("Client", text: client_name))
    |> assert_has(definition("Client email", text: client_email))
    |> assert_has(definition("Type of job", text: "Wedding"))
    |> assert_has(definition("Job price", text: "$1,234.50"))
    |> assert_has(definition("Package", text: "Wedding Deluxe"))
    |> assert_has(definition("Package description", text: "My greatest wedding package"))
  end

  feature "user sees validation errors when creating job", %{session: session} do
    session
    |> click(link("Create a Job"))
    |> fill_in(text_field("Client name"), with: " ")
    |> fill_in(text_field("Client email"), with: " ")
    |> click(option("Wedding"))
    |> click(option("Select below"))
    |> assert_has(css("label", text: "Client name can't be blank"))
    |> assert_has(css("label", text: "Client email can't be blank"))
    |> assert_has(css("label", text: "Type of job can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user sees error when creating client with duplicate email", %{
    session: session,
    user: user
  } do
    email = "taylor@example.com"

    Client.create_changeset(%{
      email: email,
      name: "anything",
      organization_id: user.organization_id
    })
    |> Repo.insert!()

    session
    |> click(link("Create a Job"))
    |> fill_in(text_field("Client email"), with: email)
    |> assert_has(css("label", text: "email has already been taken"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user sees validation errors when creating a package", %{session: session, user: user} do
    client =
      Client.create_changeset(%{
        email: "taylor@example.com",
        name: "Elizabeth Taylor",
        organization_id: user.organization_id
      })
      |> Repo.insert!()

    job =
      Job.create_changeset(%{client_id: client.id, type: "wedding"})
      |> Repo.insert!()

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
    client =
      Client.create_changeset(%{
        email: "taylor@example.com",
        name: "Elizabeth Taylor",
        organization_id: user.organization_id
      })
      |> Repo.insert!()

    Package.create_changeset(%{
      price: 100,
      name: "My Package Template",
      description: "My custom description",
      shoot_count: 2,
      organization_id: user.organization_id
    })
    |> Repo.insert!()

    job =
      Job.create_changeset(%{client_id: client.id, type: "wedding"})
      |> Repo.insert!()

    session
    |> visit("/jobs/#{job.id}/packages/new")
    |> assert_has(
      css("select[name='package[package_template_id]'] option:checked",
        text: "Select below"
      )
    )
    |> click(option("My Package Template"))
    |> assert_value(text_field("Package name"), "My Package Template")
    |> assert_value(text_field("Package description"), "My custom description")
    |> assert_value(text_field("Package price"), "$1.00")
    |> assert_value(select("Number of shoots for job"), "2")
    |> fill_in(text_field("Package name"), with: "My job package")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(definition("Client", text: "Elizabeth Taylor"))
    |> assert_has(definition("Client email", text: "taylor@example.com"))
    |> assert_has(definition("Type of job", text: "Wedding"))
    |> assert_has(definition("Job price", text: "$1.00"))
    |> assert_has(definition("Package", text: "My job package"))
    |> assert_has(definition("Package description", text: "My custom description"))
  end

  feature "user is redirected to new package page when job is not associated to package", %{
    session: session,
    user: user
  } do
    client =
      Client.create_changeset(%{
        email: "taylor@example.com",
        name: "Elizabeth Taylor",
        organization_id: user.organization_id
      })
      |> Repo.insert!()

    job =
      Job.create_changeset(%{client_id: client.id, type: "wedding"})
      |> Repo.insert!()

    session
    |> visit("/jobs/#{job.id}")

    assert current_path(session) == "/jobs/#{job.id}/packages/new"
  end

  feature "user is redirected to job show page when job is already associated to package", %{
    session: session,
    user: user
  } do
    client =
      Client.create_changeset(%{
        email: "taylor@example.com",
        name: "Elizabeth Taylor",
        organization_id: user.organization_id
      })
      |> Repo.insert!()

    package =
      Package.create_changeset(%{
        price: 10,
        name: "Package name",
        description: "Package description",
        shoot_count: 1,
        organization_id: user.organization_id
      })
      |> Repo.insert!()

    job =
      Job.create_changeset(%{client_id: client.id, type: "wedding"})
      |> Job.add_package_changeset(%{package_id: package.id})
      |> Repo.insert!()

    session
    |> visit("/jobs/#{job.id}/packages/new")

    assert current_path(session) == "/jobs/#{job.id}"
  end

  defp definition(term, opts) do
    xpath("//dt[contains(./text(), '#{term}')]/following-sibling::dd[1]", opts)
  end

  defp assert_value(session, query, value) do
    actual = session |> find(query) |> Element.value()
    assert value == actual
    session
  end
end
