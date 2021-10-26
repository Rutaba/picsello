defmodule Picsello.ManageLeadShootTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Job

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    lead =
      insert(:lead, %{
        user: user,
        type: "wedding",
        notes: "They're getting married!",
        package: %{}
      })

    [lead: lead, session: session]
  end

  feature "user adds shoot details and updates it", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Add shoot details", count: 2, at: 1))
    |> fill_in(text_field("Shoot Title"), with: " ")
    |> assert_has(css("label", text: "Shoot Title can't be blank"))
    |> fill_in(text_field("Shoot Title"), with: "chute")
    |> fill_in(text_field("Shoot Date"), with: "04052040\t1200P")
    |> find(select("Shoot Duration"), &click(&1, option("1.5 hrs")))
    |> find(select("Shoot Location"), &click(&1, option("On Location")))
    |> fill_in(text_field("Shoot Notes"), with: "my notes")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(link("chute"))
    |> click(button("Edit"))
    |> assert_value(text_field("Shoot Title"), "chute")
    |> assert_value(text_field("Shoot Date"), "2040-04-05T12:00")
    |> assert_value(select("Shoot Duration"), "90")
    |> assert_value(select("Shoot Location"), "on_location")
    |> assert_value(text_field("Shoot Notes"), "my notes")
    |> fill_in(text_field("Shoot Title"), with: " ")
    |> assert_has(css("label", text: "Shoot Title can't be blank"))
    |> fill_in(text_field("Shoot Title"), with: "updated chute")
    |> fill_in(text_field("Shoot Date"), with: "05052040\t1200P")
    |> find(select("Shoot Duration"), &click(&1, option("2 hrs")))
    |> find(select("Shoot Location"), &click(&1, option("In Studio")))
    |> fill_in(text_field("Shoot Notes"), with: "new notes")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(link("Go back to #{Job.name(lead)}"))
    |> click(link("updated chute"))
    |> click(button("Edit"))
    |> assert_value(text_field("Shoot Date"), "2040-05-05T12:00")
    |> assert_value(select("Shoot Duration"), "120")
    |> assert_value(select("Shoot Location"), "studio")
    |> assert_value(text_field("Shoot Notes"), "new notes")
  end
end
