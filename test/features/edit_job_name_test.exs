defmodule Picsello.EditJobNameTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    job = insert(:lead, user: user) |> promote_to_job()

    [job: job, session: session]
  end

  test "Edit job name", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> assert_text("Mary Jane Wedding")
    |> click(css("#meatball-manage"))
    |> click(css("li", text: "Edit job name"))
    |> assert_has(button("Save"))
    |> take_screenshot()
    |> fill_in(text_field("Name:"), with: "New Job")
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> take_screenshot()
    |> assert_text("New Job")
  end
end
