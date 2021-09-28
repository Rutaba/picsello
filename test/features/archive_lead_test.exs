defmodule Picsello.ArchiveLeadTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    lead =
      insert(:lead, %{
        user: user,
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 2,
          price: 100
        },
        shoots: [%{}, %{}]
      })

    [lead: lead, session: session]
  end

  feature "user archives lead", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Manage"))
    |> click(button("Archive lead"))
    |> click(button("Yes, archive the lead"))
    |> assert_has(css(".alert-info", text: "Lead archived"))
    |> assert_has(css("*[role='status']", text: "Lead archived"))
    |> click(button("Manage"))
    |> refute_has(button("Archive lead"))
  end
end
