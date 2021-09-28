defmodule Picsello.EditleadTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    lead =
      insert(:lead, %{
        user: user,
        type: "wedding",
        notes: "They're getting married!"
      })

    [lead: lead, session: session]
  end

  feature "user edits a lead", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Edit Lead"))
    |> assert_has(button("Cancel"))
    |> assert_value(select("Type of photography"), "wedding")
    |> assert_value(text_field("Lead notes"), "They're getting married!")
    |> click(option("Other"))
    |> fill_in(text_field("Lead notes"), with: "They're getting hitched!")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Other"))
    |> click(button("Edit Lead"))
    |> assert_value(text_field("Lead notes"), "They're getting hitched!")
  end
end
