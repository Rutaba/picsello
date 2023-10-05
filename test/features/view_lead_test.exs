defmodule Picsello.ViewLeadTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true
  import Money.Sigils

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    insert(:questionnaire,
      job_type: "family",
      is_picsello_default: true,
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
              client: %{name: client_name},
              shoots: [
                %{name: "test_name"}
              ]
            })
        )
    ]
  end

  feature "user views lead list", %{session: session, leads: leads} do
    leads
    |> Enum.each(fn lead ->
      insert(:shoot, job: lead, starts_at: ~U[2050-12-10 10:00:00Z])
    end)

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
    insert(:payment_schedule, job: lead, price: ~M[5000]USD)
    insert(:proposal, job: lead)

    insert(:shoot, job: lead, starts_at: ~U[2050-12-10 10:00:00Z])

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
    |> click(button("View inbox"))
    |> assert_path(Routes.inbox_path(PicselloWeb.Endpoint, :show, lead.id))
    |> assert_has(testid("thread-card", count: 1))
    |> find(testid("thread-card"), &assert_text(&1, "Rick Sanchez Family"))
  end

  feature "users views questionnaire", %{session: session, user: user, leads: [lead | _]} do
    package = insert(:package, %{user: user, job_type: "family"})

    lead
    |> Picsello.Job.add_package_changeset(%{package_id: package.id})
    |> Picsello.Repo.update!()

    session
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> assert_text("Booking details")
    |> find(testid("questionnaire"), &click(&1, button("Preview")))
    |> assert_text("What do you like to do as a family?")
  end
end
