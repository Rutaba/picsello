defmodule Picsello.ArchiveLeadTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    lead = insert(:lead, user: user)

    [lead: lead, session: session]
  end

  feature "user archives lead", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> click(css("#manage"))
    |> click(css("li", text: "Archive lead"))
    |> click(button("Yes, archive the lead"))
    |> assert_flash(:success, text: "Lead has been archived")
    |> assert_has(css("*[role='status']", text: "Archived"))
    |> click(button("Manage"))
    |> refute_has(button("Archive lead"))
  end
end
