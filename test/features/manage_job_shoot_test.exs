defmodule Picsello.ManageJobShootTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Shoot, Repo}

  setup :onboarded
  setup :authenticated

  def add_days(date, days), do: DateTime.add(date, days * 24 * 60 * 60)

  setup %{session: session, user: user} do
    job =
      insert(:lead, %{
        user: user,
        package: %{shoot_count: 2}
      })

    shoots =
      for(days_from_now <- [1, 2]) do
        insert(:shoot,
          name: "Shoot #{days_from_now}",
          job: job,
          starts_at: add_days(DateTime.utc_now(), days_from_now),
          notes: "These are the photographer notes for shoot #{days_from_now}."
        )
      end

    job = job |> promote_to_job()

    [job: job, session: session, shoots: shoots]
  end

  def shoot_path(job, shoot_number),
    do: Routes.shoot_path(PicselloWeb.Endpoint, :jobs, job.id, shoot_number)

  def job_path(job), do: Routes.job_path(PicselloWeb.Endpoint, :jobs, job.id)

  feature "user views job shoot", %{session: session, job: job, shoots: [shoot1 | _]} do
    starts_at = ~U[1981-04-05T00:00:00Z]

    shoot1 |> Shoot.update_changeset(%{starts_at: starts_at}) |> Repo.update!()

    session
    |> visit(shoot_path(job, 1))
    |> assert_has(css("header h1", text: shoot1.name))
    |> assert_has(definition("Shoot Location", text: "In Client's Home"))
    |> assert_has(definition("Shoot Duration", text: "15 mins"))
    |> assert_has(definition("Shoot Notes", text: "photographer notes for shoot 1"))
    |> assert_has(css("time", text: "APRIL\n05\n12:00 AM"))
  end

  feature "user reschedules job shoot", %{session: session, job: job, shoots: [shoot1, shoot2]} do
    session
    |> visit(job_path(job))
    |> click(link(shoot1.name))
    |> click(button("edit shoot"))
    |> assert_text("Edit Shoot")
    |> assert_path(shoot_path(job, 1))
    |> assert_has(css("header h1", text: shoot1.name))
    |> fill_in_date(css("#shoot_starts_at", visible: false),
      with: add_days(shoot2.starts_at, 1)
    )
    |> click(button("Save"))
    |> assert_path(shoot_path(job, 2))
    |> assert_has(css("header h1", text: shoot1.name))
    |> click(link("Go back"))
    |> click(link(shoot2.name))
    |> assert_path(shoot_path(job, 1))
  end

  feature "user adds address to shoot", %{session: session, job: job} do
    address = "320 1st St N, Jax Beach, FL"

    session
    |> visit(shoot_path(job, 1))
    |> click(button("edit shoot"))
    |> click(link("Add an address"))
    |> fill_in(text_field("Shoot Address"), with: address)
    |> click(button("Save"))
    |> assert_has(definition("Shoot Location", text: "In Client's Home #{address}"))
    |> click(button("edit shoot"))
    |> assert_has(text_field("Shoot Address", value: address))
    |> click(link("Remove address"))
    |> click(button("Save"))
    |> assert_has(definition("Shoot Location", text: "In Client's Home"))
  end
end
