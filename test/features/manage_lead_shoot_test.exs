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

    insert(:package_payment_schedule, %{package: lead.package})
    [lead: lead, session: session]
  end

  feature "user adds shoot details and updates it", %{session: session, lead: lead} do
    lead_path = "/leads/#{lead.id}"

    session
    |> visit(lead_path)
    |> scroll_into_view(testid("booking-summary"))
    |> assert_text("$1.00 to To Book")
    |> click(button("Add shoot details", count: 2, at: 1))
    |> fill_in(text_field("Shoot Title"), with: " ")
    |> assert_has(css("label", text: "Shoot Title can't be blank"))
    |> fill_in(text_field("Shoot Title"), with: "chute")
    |> click(css("#shoot-time"))
    |> fill_in(css(".numInput.cur-year"), with: "2040")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("April")))
    |> click(css("[aria-label='April 5, 2040']"))
    |> find(select("Shoot Duration"), &click(&1, option("1.5 hrs")))
    |> find(select("Shoot Location"), &click(&1, option("On Location")))
    |> fill_in(text_field("Shoot Notes"), with: "my notes")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> click(link("chute"))
    |> wait_for_path_to_change_from(lead_path)
    |> click(button("Edit"))
    |> assert_value(text_field("Shoot Title"), "chute")
    |> click(css("#shoot-time"))
    |> fill_in(css(".numInput.cur-year"), with: "2040")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("May")))
    |> click(css("[aria-label='May 5, 2040']"))
    |> assert_value(select("Shoot Duration"), "90")
    |> assert_value(select("Shoot Location"), "on_location")
    |> assert_value(text_field("Shoot Notes"), "my notes")
    |> fill_in(text_field("Shoot Title"), with: " ")
    |> assert_has(css("label", text: "Shoot Title can't be blank"))
    |> fill_in(text_field("Shoot Title"), with: "updated chute")
    |> click(css("#shoot-time"))
    |> fill_in(css(".numInput.cur-year"), with: "2040")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("May")))
    |> click(css("[aria-label='May 5, 2040']"))
    |> find(select("Shoot Duration"), &click(&1, option("2 hrs")))
    |> find(select("Shoot Location"), &click(&1, option("In Studio")))
    |> fill_in(text_field("Shoot Notes"), with: "new notes")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(link("Go back to #{Job.name(lead)}"))
    |> assert_path(lead_path)
    |> click(link("updated chute"))
    |> wait_for_path_to_change_from(lead_path)
    |> click(button("Edit"))
    |> assert_value(css("#shoot_starts_at", visible: false), "2040-05-05")
    |> assert_value(select("Shoot Duration"), "120")
    |> assert_value(select("Shoot Location"), "studio")
    |> assert_value(text_field("Shoot Notes"), "new notes")
  end
end
