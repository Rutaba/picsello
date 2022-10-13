defmodule Picsello.ViewLeadTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    insert(:questionnaire,
      job_type: "family",
      questions: [
        %{
          type: "textarea",
          prompt: "What do you like to do as a family?",
          optional: false
        }
      ]
    )

    [
      leads:
        for(
          {client_name, job_type} <- [{"Rick Sanchez", "family"}, {"Morty Smith", "wedding"}],
          do:
            insert(:lead, %{
              user: user,
              type: job_type,
              client: %{name: client_name}
            })
        )
    ]
  end

  feature "user views lead list", %{session: session} do
    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads))
    |> assert_has(link("Rick Sanchez Family"))
    |> click(link("Morty Smith Wedding"))
    |> click(css(":not(nav) > a", text: "Leads"))
    |> click(link("Rick Sanchez Family"))
    |> assert_has(css("h1", text: "Rick Sanchez Family"))
  end

  feature "photographer sees scheduled reminder email date", %{
    session: session,
    leads: [lead | _]
  } do
    insert(:proposal, job: lead)

    first_reminder_on =
      DateTime.utc_now() |> DateTime.add(3 * 24 * 60 * 60) |> Calendar.strftime("%B %d, %Y")

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads))
    |> click(link("Rick Sanchez Family"))
    |> assert_text("Email scheduled for #{first_reminder_on}")
  end

  feature "user views inbox card on lead page", %{
    session: session,
    leads: [lead | _]
  } do
    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> assert_inner_text(testid("inbox"), "0 new messages")
    |> find(testid("inbox"), &click(&1, button("Send message")))
    |> within_modal(&assert_text(&1, "Send an email"))
    |> within_modal(&click(&1, button("Cancel")))
    |> click(button("Go to inbox"))
    |> assert_path(Routes.inbox_path(PicselloWeb.Endpoint, :show, lead.id))
    |> assert_has(testid("thread-card", count: 1))
    |> find(testid("thread-card"), &assert_text(&1, "Rick Sanchez Family"))
  end

  feature "users views questionnaire", %{session: session, leads: [lead | _]} do
    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> assert_text("Booking details")
    |> find(testid("questionnaire"), &click(&1, button("View")))
    |> assert_text("Read-only")
    |> assert_text("What do you like to do as a family?")
  end

  feature "edit name of lead changes name", %{
    session: session,
    leads: [lead | _]
  } do
    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> click(button("manage"))
    |> click(link("Edit lead name"))
    |> assert_has(button("Save"))
    |> fill_in(text_field("Client name:"), with: "New")
    |> assert_text("New Family")
  end
end
