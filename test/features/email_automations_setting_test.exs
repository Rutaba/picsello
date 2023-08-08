defmodule Picsello.EmailAutomationsTest do
  use Picsello.FeatureCase, async: true
  import Ecto.Query

  setup :onboarded
  setup :authenticated

  setup do
    user = Picsello.Repo.one(from(u in Picsello.Accounts.User))
    for {state, index} <- Enum.with_index(["client_contact", "manual_thank_you_lead", "manual_booking_proposal_sent"]) do
    insert(:email_preset, job_type: "wedding", organization_id: user.organization_id, status: :active, email_automation_pipeline_id: index+1, state: "client_contact", type: "lead")
    end

    for {state, index} <- Enum.with_index(["pays_retainer", "pays_retainer_offline", "booking_event", "before_shoot", "balance_due", "offline_payment", "paid_offline_full", "paid_full", "shoot_thanks", "post_shoot"]) do
      insert(:email_preset, job_type: "wedding", organization_id: user.organization_id, status: :active, email_automation_pipeline_id: index+4, state: state, type: "job")
    end

    for {state, index} <- Enum.with_index(["manual_gallery_send_link", "cart_abandoned", "gallery_expiration_soon", "gallery_password_changed", "manual_send_proofing_gallery", "manual_send_proofing_gallery_finals", "order_confirmation_physical", "order_confirmation_digital", "order_confirmation_digital_physical", "digitals_ready_download", "order_shipped", "order_delayed", "order_arrived"]) do
      insert(:email_preset, job_type: "wedding", organization_id: user.organization_id, status: :active, email_automation_pipeline_id: index+14, state: state, type: "gallery")
    end

    {:ok, user: user}
  end

  feature "Checking side-manue click effects on headings and text color", %{session: session} do
    session
    |> visit("/email-automations")
    |> assert_text("Leads")
    |> assert_text("Jobs")
    |> assert_text("Galleries")
    |> assert_has(css("h2", text: "Wedding Automations", count: 1))
    |> assert_has(css("h2", text: "Event Automations", count: 0))
    |> assert_has(css("h2", text: "Newborn Automations", count: 0))
    |> find(css("div[testid='wedding']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 1))
    end)
    |> find(css("div[testid='newborn']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 0))
    end)
    |> find(css("div[testid='event']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 0))
    end)
    |> click(css("span", text: "Newborn"))
    |> assert_has(css("h2", text: "Newborn Automations", count: 1))
    |> assert_has(css("h2", text: "Event Automations", count: 0))
    |> assert_has(css("h2", text: "Wedding Automations", count: 0))
    |> find(css("div[testid='newborn']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 1))
    end)
    |> find(css("div[testid='event']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 0))
    end)
    |> find(css("div[testid='wedding']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 0))
    end)
    |> click(css("span", text: "Event"))
    |> assert_has(css("h2", text: "Event Automations", count: 1))
    |> assert_has(css("h2", text: "Newborn Automations", count: 0))
    |> assert_has(css("h2", text: "Wedding Automations", count: 0))
    |> find(css("div[testid='event']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 1))
    end)
    |> find(css("div[testid='wedding']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 0))
    end)
    |> find(css("div[testid='newborn']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 0))
    end)
    |> click(css("span", text: "Wedding"))
    |> assert_has(css("h2", text: "Event Automations", count: 0))
    |> assert_has(css("h2", text: "Newborn Automations", count: 0))
    |> assert_has(css("h2", text: "Wedding Automations", count: 1))
    |> find(css("div[testid='wedding']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 1))
    end)
    |> find(css("div[testid='newborn']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 0))
    end)
    |> find(css("div[testid='event']"), fn div ->
      assert_has(div, css(".text-blue-planning-300", count: 0))
    end)
  end

  feature "testing total number of pipelines on email-automations setting page", %{session: session} do
    session
    |> visit("/email-automations")
    |> find(css("div[testid='main-section-of-page']"), fn div ->
      assert_has(div, css("section", count: 26))
    end)
  end

  feature "Testing dropdowns-toggles for sub-category and pipeline sections", %{session: session} do
    session
    |> visit("/email-automations")
    |> assert_has(css("span", text: "Client contacts you", count: 1))
    |> click(css("div[phx-value-section_id='Inquiry emails']"))
    |> assert_has(css("span", text: "Client contacts you", count: 0))
    |> click(css("div[phx-value-section_id='Inquiry emails']"))
    |> assert_has(css("span", text: "Client contacts you", count: 1))
    |> assert_has(button("Edit time", count: 0))
    |> click(css("span", text: "Client contacts you"))
    |> assert_has(button("Edit time", count: 1))
    |> click(css("span", text: "Client contacts you"))
    |> assert_has(button("Edit time", count: 0))
  end

  feature "Delete button is disabled for first email", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Wedding"))
    |> click(css("span", text: "Client contacts you"))
    |> assert_has(css("span", text: "Can't delete first email; disable the entire sequence if you don't want it to send", count: 0))
    |> hover(css("button[title='remove']"))
    |> assert_has(css("span", text: "Can't delete first email; disable the entire sequence if you don't want it to send", count: 1))
  end

  feature "toggle to disable/enable the entire pipeline and its effects on UI", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Wedding"))
    |> click(css("span", text: "Client contacts you"))
    |> assert_has(css("span", text: "Disabled", count: 0))
    |> find(css("div[testid='email-main-icon']"), fn div ->
      assert_has(div, css("use[href='/images/icons.svg#envelope']", count: 1))
    end)
    |> find(css("div[testid='email-main-icon']"), fn div ->
      assert_has(div, css("use[href='/images/icons.svg#close-x']", count: 0))
    end)
    |> click(css("div[testid='enable-1']", text: "Enable automation"))
    |> assert_flash(:success, text: "Pipeline successfully disabled")
    |> find(css("div[testid='email-main-icon']"), fn div ->
      assert_has(div, css("use[href='/images/icons.svg#envelope']", count: 0))
    end)
    |> find(css("div[testid='email-main-icon']"), fn div ->
      assert_has(div, css("use[href='/images/icons.svg#close-x']", count: 1))
    end)
    |> assert_has(css("span", text: "Disabled", count: 1))
    |> click(css("div[testid='disable-1']", text: "Disable automation"))
    |> assert_flash(:success, text: "Pipeline successfully enabled")
    |> assert_has(css("span", text: "Disabled", count: 0))
    |> find(css("div[testid='email-main-icon']"), fn div ->
      assert_has(div, css("use[href='/images/icons.svg#envelope']", count: 1))
    end)
    |> find(css("div[testid='email-main-icon']"), fn div ->
      assert_has(div, css("use[href='/images/icons.svg#close-x']", count: 0))
    end)
  end

  feature "Testing Edit-time button and modal", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Wedding"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 0))
    |> click(css("span", text: "Client contacts you"))
    |> assert_has(button("Edit time", count: 1))
    |> assert_has(button("Edit email", count: 1))
    |> assert_has(css(".modal", count: 0))
    |> assert_has(css("span", text: "Send email immediately", count: 1))
    |> click(button("Edit time"))
    |> assert_has(css(".modal", count: 1))
    |> assert_text("Edit Email Automation Settings")
    |> assert_text("Send email: Client contacts you")
    |> assert_text("Choose whether or not this email should send")
    |> assert_text("Choose when you’d like your email to send")
    |> assert_text("Email timing")
    |> assert_text("Email Status")
    |> assert_text("Job Automation")
    |> click(css("input[id='email_preset_immediately_false']"))
    |> fill_in(css("input[name='email_preset[count]']"), with: "2")
    |> click(button("Save"))
    |> assert_has(css("span", text: "Send email immediately", count: 0))
    |> assert_text("Send 2 hours after")
    |> assert_has(css(".modal", count: 0))
    |> click(button("Edit time"))
    |> assert_has(css(".modal", count: 1))
    |> click(css("input[id='email_preset_immediately_true']"))
    |> click(button("Save"))
    |> assert_has(css("span", text: "Send email immediately", count: 1))
  end

  feature "Effect of edited time, on UI of edit-email modal", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Wedding"))
    |> scroll_into_view(css("span", text: "Client contacts you"))
    |> click(css("span", text: "Client contacts you"))
    |> click(button("Edit email"))
    |> assert_has(css("p", text: "Send email immediately", count: 1))
    |> assert_has(css("p", text: "Send email 2 hours after client contacts you", count: 0))
    |> click(button("Close"))
    |> click(button("Edit time"))
    |> click(css("input[id='email_preset_immediately_false']"))
    |> fill_in(css("input[id='email_preset_count']"), with: "2")
    |> click(button("Save"))
    |> click(button("Edit email"))
    |> assert_has(css("p", text: "Send email immediately", count: 0))
    |> assert_has(css("p", text: "Send email 2 hours after client contacts you", count: 1))
  end

  # click issue
  feature "toggle in Edit-time modal, for enable/disble email", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Wedding"))
    |> scroll_into_view(css("span", text: "Client contacts you"))
    |> click(css("span", text: "Client contacts you"))
    |> assert_has(css("span", text: "Disabled", count: 0))
    |> click(button("Edit time"))
    |> scroll_into_view(css("div[testid='toggle-in-edit-email-modal']"))
    |> click(css("div[testid='enable-toggle-in-edit-email-modal']"))
    |> click(button("Save"))
    |> assert_has(css("span", text: "Disabled", count: 1))
    |> click(button("Edit time"))
    |> click(css("div[testid='disable-toggle-in-edit-email-modal']"))
    |> click(button("Save"))
    |> assert_has(css("span", text: "Disabled", count: 0))
  end

  feature "Manually triggered automation's first email, does not have edit time button", %{session: session} do
    session
    |> visit("/email-automations")
    |> scroll_into_view(css("span", text: "Thank you for contacting me"))
    |> click(css("span", text: "Thank you for contacting me"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 1))
    |> click(css("span", text: "Thank you for contacting me"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 0))
    |> scroll_into_view(css("span", text: "Proposal Sent/Initiated"))
    |> click(css("span", text: "Proposal Sent/Initiated"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 1))
    |> click(css("span", text: "Proposal Sent/Initiated"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 0))
    |> scroll_into_view(css("span", text: "Send Gallery Link"))
    |> click(css("span", text: "Send Gallery Link"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 1))
    |> click(css("span", text: "Send Gallery Link"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 0))
    |> scroll_into_view(css("span", text: "Send Proofing Gallery For Selection"))
    |> click(css("span", text: "Send Proofing Gallery For Selection"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 1))
    |> click(css("span", text: "Send Proofing Gallery For Selection"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 0))
    |> scroll_into_view(css("span", text: "Send Proofing Gallery Finals"))
    |> click(css("span", text: "Send Proofing Gallery Finals"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 1))
    |> click(css("span", text: "Send Proofing Gallery Finals"))
    |> assert_has(button("Edit time", count: 0))
    |> assert_has(button("Edit email", count: 0))
  end

  feature "Testing Edit email button and modal", %{session: session} do
    session
    |> visit("/email-automations")
    |> click(css("span", text: "Wedding"))
    |> scroll_into_view(css("span", text: "Client contacts you"))
    |> click(css("span", text: "Client contacts you"))
    |> click(button("Edit email"))
    |> assert_has(css("button[disabled]", text: "Next", count: 0))
    |> assert_has(css(".ql-blank", count: 0))
    |> click(css("button[id='clear-description']"))
    |> assert_has(css("button[disabled]", text: "Next", count: 1))
    |> assert_has(css(".ql-blank", count: 1))
    |> click(css("button", text: "Close"))
    |> assert_has(css("div", text: "Demo Name", count: 0))
    |> click(button("Edit email"))
    |> assert_text("Edit Wedding Email")
    |> assert_text("Lead:")
    |> assert_text("Select email preset")
    |> assert_text("Subject Line")
    |> assert_text("Private Name")
    |> assert_text("Email Content")
    |> assert_text("View email variables")
    |> assert_has(css("div[testid='variables']", count: 0))
    |> click(css("button[id='view-variables']"))
    |> assert_has(css("div[testid='variables']", count: 1))
    |> click(css("use[href='/images/icons.svg#close-x']", count: 2, at: 1))
    |> assert_has(css("div[testid='variables']", count: 0))
    |> assert_has(css("span", text: "Step 1", count: 1))
    |> assert_has(css("span", text: "Step 2", count: 0))
    |> fill_in(css("input[placeholder='Inquiry Email']"), with: "Demo Name")
    |> click(button("Next"))
    # Onward: Step 2 of Modal not tested, due to mock issue.
    |> assert_text("Preview Wedding Email")
    |> assert_text("Lead: Inquiry emails")
    |> assert_text("Check out how your client will see your emails. We’ve put in some placeholder data to visualize the variables.")
    |> assert_has(css("span", text: "Step 2", count: 1))
    |> assert_has(css("span", text: "Step 1", count: 0))
    |> click(button("Go back"))
    |> assert_has(css("span", text: "Step 2", count: 0))
    |> assert_has(css("span", text: "Step 1", count: 1))
    |> click(button("Next"))
    |> click(button("Save"))
    |> assert_has(css("div", text: "Demo Name", count: 1))
  end
end
