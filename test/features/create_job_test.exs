defmodule Picsello.CreateJobTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Client, Repo, Job, Package}

  setup :authenticated

  feature "user creates job", %{session: session} do
    session
    |> click(link("Create a Job"))
    |> fill_in(text_field("Client name"), with: "Elizabeth Taylor")
    |> fill_in(text_field("Client email"), with: "taylor@example.com")
    |> click(option("Wedding"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h2", text: "Elizabeth Taylor Wedding"))
    |> assert_has(css("h1", text: "Add Package"))
    |> fill_in(text_field("Package name"), with: "Wedding Deluxe")
    |> fill_in(text_field("Package description"), with: "My greatest wedding package")
    |> fill_in(text_field("Package price"), with: "1234")
    |> click(css("option", text: "2"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
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
end
