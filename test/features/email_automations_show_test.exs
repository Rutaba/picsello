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

  feature "Testing categories and pipelines related to a lead", %{session: session} do
    session
    |> click(button("Leads"))
    |> click(button("Create a lead"))
    |> click(button("Add a new client"))
    |> fill_in(css("input[id='job_client_email']"), with: "example@example.com")
    |> fill_in(css("input[id='job_client_name']"), with: "MyClient")
    |> scroll_into_view(css("div[testid='wedding']"))
    |> click(css("div[testid='wedding']"))
    |> click(css("div[testid='wedding']"))
    |> click(css("div[testid='wedding']"))
    |> click(button("Save"))
    |> find(css("div[data-testid='inbox']"), fn div ->
      click(div, button("View all"))
    end)
    |> find(css("div[testid='main-area']", count: 2, at: 0), fn div ->
      assert_has(div, css("div", text: "Leads", count: 2))
      assert_has(div, css("div", text: "Jobs", count: 0))
      assert_has(div, css("div", text: "Galleries", count: 0))
    end)
    |> find(css("div[testid='main-area']", count: 2, at: 1), fn div ->
      assert_has(div, css("div", text: "Leads", count: 0))
      assert_has(div, css("div", text: "Jobs", count: 2))
      assert_has(div, css("div", text: "Galleries", count: 0))
    end)
    |> assert_has(css("div[testid='pipeline-section']", count: 12))       # should be 13 but one pipeline of lead is not visible in test, but in real.

  end

  feature "testing categories and pipelines related to a job", %{session: session} do
    session
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> click(button("Next", at: 0))
    |> click(button("Add a new client"))
    |> fill_in(css("input[id='form-job_details_client_email']"), with: "example@example.com")
    |> fill_in(css("input[id='form-job_details_client_name']"), with: "MyClient")
    |> scroll_into_view(css("div[testid='wedding']"))
    |> click(css("div[testid='wedding']"))
    |> click(css("div[testid='wedding']"))
    |> click(css("div[testid='wedding']"))
    |> click(button("Next"))
    |> fill_in(css("input[id='form-package_payment_name']"), with: "Demo Title")
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> click(button("Finish"))
    |> click(css("span", text: "MyClient Wedding"))
    |> find(css("div[data-testid='inbox']"), fn div ->
      click(div, button("View all"))
    end)
    |> find(css("div[testid='main-area']", count: 1, at: 0), fn div ->
      assert_has(div, css("div", text: "Leads", count: 0))
      assert_has(div, css("div", text: "Jobs", count: 2))
      assert_has(div, css("div", text: "Galleries", count: 0))
    end)
    |> assert_has(css("div[testid='pipeline-section']", count: 10))
  end

  feature "testing categories and pipelines related to a job when it is created from gallery", %{session: session} do
    session
    |> click(button("Galleries"))
    |> click(button("Create a gallery", count: 2, at: 0))
    |> click(button("Next", count: 2, at: 0))
    |> click(button("Add a new client"))
    |> fill_in(css("input[id='form-details_client_email']"), with: "example@example.com")
    |> fill_in(css("input[id='form-details_client_name']"), with: "MyClient")
    |> scroll_into_view(css("div[testid='wedding']"))
    |> click(css("div[testid='wedding']"))
    |> click(css("div[testid='wedding']"))
    |> click(css("div[testid='wedding']"))
    |> click(button("Next"))
    |> click(button("Save"))
    |> wait_for_enabled_submit_button()
    |> visit("/jobs")
    |> click(css("p", text: "MyClient", count: 2, at: 0))
    |> find(css("div[data-testid='inbox']"), fn div ->
      click(div, button("View all"))
    end)
    |> find(css("div[testid='main-area']", count: 2, at: 0), fn div ->
      assert_has(div, css("div", text: "Leads", count: 0))
      assert_has(div, css("div", text: "Jobs", count: 2))
      assert_has(div, css("div", text: "Galleries: MyClient wedding", count: 0))
    end)
    |> find(css("div[testid='main-area']", count: 2, at: 1), fn div ->
      assert_has(div, css("div", text: "Leads", count: 0))
      assert_has(div, css("div", text: "Jobs", count: 0))
      assert_has(div, css("div", text: "Galleries: MyClient wedding", count: 2))
    end)
    |> visit("/jobs")
    |> click(css("p", text: "MyClient", count: 2, at: 0))
    |> scroll_into_view(css("section[testid='gallery section']"))
    |> find(css("section[testid='gallery section']"), fn div ->
      click(div, button("Add another gallery"))
    end)
    |> click(button("Get Started", count: 2, at: 0))
    |> visit("/jobs")
    |> click(css("p", text: "MyClient", count: 2, at: 0))
    |> find(css("div[data-testid='inbox']"), fn div ->
      click(div, button("View all"))
    end)
    |> find(css("div[testid='main-area']", count: 3, at: 0), fn div ->
      assert_has(div, css("div", text: "Leads", count: 0))
      assert_has(div, css("div", text: "Jobs", count: 2))
      assert_has(div, css("div", text: "Galleries: MyClient wedding", count: 0))
      assert_has(div, css("div", text: "Galleries: MyClient Wedding 2", count: 0))
    end)
    |> find(css("div[testid='main-area']", count: 3, at: 1), fn div ->
      assert_has(div, css("div", text: "Leads", count: 0))
      assert_has(div, css("div", text: "Jobs", count: 0))
      assert_has(div, css("div", text: "Galleries: MyClient Wedding 2", count: 2))
      assert_has(div, css("div", text: "Galleries: MyClient wedding", count: 0))
    end)
    |> find(css("div[testid='main-area']", count: 3, at: 2), fn div ->
      assert_has(div, css("div", text: "Leads", count: 0))
      assert_has(div, css("div", text: "Jobs", count: 0))
      assert_has(div, css("div", text: "Galleries: MyClient wedding", count: 2))
      assert_has(div, css("div", text: "Galleries: MyClient Wedding 2", count: 0))
    end)
  end
end
