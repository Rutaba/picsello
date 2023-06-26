defmodule Picsello.EmailAutomationsTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup do

    Tesla.Mock.mock_global(fn
      %{method: :get} ->
        body = %{"versions" => [%{"html_content" => "TEMPLATE_PREVIEW", "active" => 1}]}
        %Tesla.Env{status: 200, body: body}
    end)

  end


  feature "Checking side-manue click effects on heading", %{session: session} do
    session
    # |> click(testid("subnav-Settings"))
    # |> click(css("[href='/email-automations']"))
    # |> assert_path("/email-automations")
    |> visit("/email-automations")
    |> assert_text("Leads")
    |> assert_text("Jobs")
    |> assert_text("Galleries")
    |> assert_has(css("h2", text: "Type event Automations", count: 0))
    |> assert_has(css("h2", text: "Type newborn Automations", count: 0))
    |> click(css("span", text: "Newborn"))
    |> assert_has(css("h2", text: "Type newborn Automations", count: 1))
    |> assert_has(css("h2", text: "Type event Automations", count: 0))
    |> click(css("span", text: "Event"))
    |> assert_has(css("h2", text: "Type event Automations", count: 1))
    |> assert_has(css("h2", text: "Type newborn Automations", count: 0))
    |> click(css("span", text: "Wedding"))
    |> assert_has(css("h2", text: "Type event Automations", count: 0))
    |> assert_has(css("h2", text: "Type newborn Automations", count: 0))
    |> assert_has(css("h2", text: "Type wedding Automations", count: 1))
  end


  feature "Adding one email to Galleries category", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Send Gallery Link"))
    |> assert_has(css(".modal-container", count: 0))
    |> assert_has(css("div", text: "Share Finals Album", count: 0))
    |> click(button("Add email"))
    |> assert_has(css(".modal-container"))
    |> assert_text("Add Wedding Email Step: Timing")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Edit Email")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Preview Email")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Successfully created")
    |> assert_has(css("span", text: "1 emails", count: 3))
    |> assert_text("Share Finals Album")
    |> assert_text("Send email immediately")
    |> assert_has(button("Edit time"))
    |> assert_has(button("Edit email"))
  end

  feature "Checking buttons; Edit email and time, and their modals UI", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Send Gallery Link"))
    |> assert_has(css(".modal-container", count: 0))
    |> assert_has(css("div", text: "Share Finals Album", count: 0))
    |> click(button("Add email"))
    |> assert_has(css(".modal-container"))
    |> assert_text("Add Wedding Email Step: Timing")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Edit Email")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Preview Email")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Successfully created")
    |> assert_has(css("span", text: "1 emails", count: 3))
    |> assert_text("Share Finals Album")
    |> assert_text("Send email immediately")
    |> assert_has(button("Edit time"))
    |> assert_has(button("Edit email"))
    |> assert_has(css(".modal", count: 0))
    |> click(button("Edit time"))
    |> assert_has(css(".modal"))
    |> click(button("Save"))
    |> assert_has(css(".modal", count: 0))
    |> click(button("Edit time"))
    |> assert_has(css(".modal"))
    |> click(button("Close"))
    |> assert_has(css(".modal", count: 0))
    |> click(button("Edit time"))
    |> assert_has(css(".modal"))
    |> click(css("button[title='cancel']", count: 2, at: 0))
    |> assert_has(css(".modal", count: 0))
    |> click(button("Edit email"))
    |> assert_has(css(".modal"))
    |> assert_text("Edit Wedding Email")
    |> click(css("select"))
    |> click(css("option", text: "Send gallery link" ))
    |> click(button("Next"))
    |> assert_text("Preview Wedding Email")
    |> assert_has(css("select", count: 0))
    |> click(button("Go back"))
    |> assert_has(css("select"))
    |> click(button("Next"))
    |> click(button("Save"))
    |> assert_text("Send gallery link")
  end




end
