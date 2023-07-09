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
    |> visit("/email-automations")
    |> assert_text("Leads")
    |> assert_text("Jobs")
    |> assert_text("Galleries")
    |> assert_has(css("h2", text: "Event Automations", count: 0))
    |> assert_has(css("h2", text: "Newborn Automations", count: 0))
    |> click(css("span", text: "Newborn"))
    |> assert_has(css("h2", text: "Newborn Automations", count: 1))
    |> assert_has(css("h2", text: "Event Automations", count: 0))
    |> click(css("span", text: "Event", count: 2, at: 0))           # Where is 2nd element???
    |> assert_has(css("h2", text: "Event Automations", count: 1))
    |> assert_has(css("h2", text: "Newborn Automations", count: 0))
    |> click(css("span", text: "Wedding"))
    |> assert_has(css("h2", text: "Event Automations", count: 0))
    |> assert_has(css("h2", text: "Newborn Automations", count: 0))
    |> assert_has(css("h2", text: "Wedding Automations", count: 1))
  end

  feature "Adding one email to Galleries category", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Send Gallery Link"))
    |> assert_has(css(".modal-container", count: 0))
    |> assert_has(css("span", text: "1 emails", count: 0))
    |> click(button("Add email"))
    |> assert_has(css(".modal-container"))
    |> assert_text("Add Wedding Email Step: Timing")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Edit Email")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Preview Email")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Successfully created")
    |> assert_has(css("span", text: "1 emails", count: 3))            # But we see only 2 elements in code. Her are 3, why???
    |> assert_has(css("div", text: "Send gallery link", count: 11))            # 11 elements are visible (we inserted only one). Why???
    |> assert_text("Send email immediately")
    |> assert_has(button("Edit time"))
    |> assert_has(button("Edit email"))
  end

  feature "Adding two emails to Galleries catefory and delete button testing", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Send Gallery Link"))
    |> assert_has(css(".modal-container", count: 0))
    |> click(button("Add email"))
    |> assert_has(css(".modal-container"))
    |> assert_text("Add Wedding Email Step: Timing")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Edit Email")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Preview Email")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Successfully created")
    |> assert_has(css("span", text: "1 emails", count: 3))            # But we see only 2 elements in code. Her are 3, why???
    |> assert_has(css("div", text: "Send gallery link", count: 11))            # 11 elements are visible (we inserted only one). Why???
    |> assert_text("Send email immediately")
    |> assert_has(button("Edit time"))
    |> assert_has(button("Edit email"))
    |> assert_has(css("button[title='remove']"))
    |> assert_has(css(".modal-container", count: 0))
    |> click(button("Add email"))
    |> assert_has(css(".modal-container"))
    |> assert_text("Add Wedding Email Step: Timing")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Edit Email")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Preview Email")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Successfully created")
    |> assert_has(css("span", text: "2 emails", count: 3))            # But we see only 2 elements in code. Her are 3, why???
    |> assert_has(css("div", text: "Send gallery link", count: 16))   # 16 elements are visible (we inserted only two). Why???
    |> assert_text("Send email immediately")
    |> assert_has(button("Edit time", count: 2))
    |> assert_has(button("Edit email", count: 2))
    |> assert_has(css("button[title='remove']", count: 2))
    |> click(css("button[title='remove']", count: 2, at: 1))
    |> assert_has(button("Edit time"))
    |> assert_has(button("Edit email"))
    |> assert_has(css("button[title='remove']"))
    |> assert_has(css("span", text: "Can't delete first email; disable the entire sequence if you don't want it to send", count: 0))
    |> hover(css("button[phx-click='delete-email']"))
    |> assert_has(css("span", text: "Can't delete first email; disable the entire sequence if you don't want it to send"))
  end

  feature "Enable/disable toggle button of the pipeline", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Send Gallery Link"))
    |> click(css("div", text: "Disable automation", count: 9, at: 0))   # Why 9 elements are present here???
    # |> assert_flash(:success, text: "Pipeline successfully enabled")
  end

  feature "Checking buttons; 'Edit email' and 'Edit time', and their modals UI", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Send Gallery Link"))
    |> assert_has(css(".modal-container", count: 0))
    |> click(button("Add email"))
    |> assert_has(css(".modal-container"))
    |> assert_text("Add Wedding Email Step: Timing")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Edit Email")
    |> click(button("Next"))
    |> assert_text("Add Wedding Email Step: Preview Email")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Successfully created")
    |> assert_has(css("span", text: "1 emails", count: 3))            # But we see only 2 elements in code. Her are 3, why???
    |> assert_has(css("div", text: "Send gallery link", count: 11))   # 11 elements are visible (we inserted only one). Why???
    |> assert_text("Send email immediately")
    |> assert_has(button("Edit time"))
    |> assert_has(button("Edit email"))
    # Testing 'Edit time' button
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
    |> assert_has(css("div", text: "Share Proofing Album", count: 0))
    # Testing 'Edit email' button
    |> click(button("Edit email"))
    |> assert_has(css(".modal"))
    |> assert_text("Edit Wedding Email")
    |> click(css("select"))
    |> click(css("option", text: "Share Proofing Album" ))
    |> click(button("Next"))
    |> assert_text("Preview Wedding Email")
    |> assert_has(css("select", count: 0))
    |> click(button("Go back"))
    |> assert_has(css("select"))
    |> click(button("Next"))
    |> click(button("Save"))
    |> assert_has(css("div", text: "Share Proofing Album", count: 11))      # 11 elements are visible (we inserted only one). Why???
    |> assert_has(css("div", text: "Send gallery link", count: 0))
  end




end
