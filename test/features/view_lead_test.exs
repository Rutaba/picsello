defmodule Picsello.ViewLeadTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
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
    |> visit("/")
    |> click(link("View current leads"))
    |> assert_has(link("Rick Sanchez Family"))
    |> click(link("Morty Smith Wedding"))
    |> click(link("Leads"))
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
    |> visit("/")
    |> click(link("View current leads"))
    |> click(link("Rick Sanchez Family"))
    |> assert_text("Email scheduled for #{first_reminder_on}")
  end
end
