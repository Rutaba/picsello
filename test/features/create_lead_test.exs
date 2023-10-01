defmodule Picsello.CreateLeadTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    client =
      insert(:client,
        user: user,
        name: "Elizabeth Taylor",
        email: "taylor@example.com",
        phone: "(210) 111-1234"
      )

    base_price = %Money{amount: 10_000, currency: :USD}
    download_each_price = %Money{amount: 300, currency: :USD}
    buy_all = %Money{amount: 5000, currency: :USD}
    print_credits = %Money{amount: 1500, currency: :USD}

    insert(:package_template,
      user: user,
      job_type: "other",
      name: "best other",
      shoot_count: 1,
      description: "desc",
      base_price: base_price,
      buy_all: buy_all,
      print_credits: print_credits,
      download_count: 1,
      download_each_price: download_each_price
    )

    insert(:package_template,
      user: user,
      job_type: "wedding",
      name: "best wedding",
      shoot_count: 1,
      description: "desc",
      base_price: base_price,
      buy_all: buy_all,
      print_credits: print_credits,
      download_count: 1,
      download_each_price: download_each_price
    )

    template =
      insert(:package_template,
        user: user,
        job_type: "event",
        name: "best event",
        shoot_count: 1,
        description: "desc",
        base_price: base_price,
        buy_all: buy_all,
        print_credits: print_credits,
        download_count: 1,
        download_each_price: download_each_price
      )

    Mix.Tasks.ImportQuestionnaires.run(nil)
  end

  feature "user creates lead with existing client", %{session: session} do
    session
    |> click(button("Actions"))
    |> click(button("Create lead"))
    |> fill_in(text_field("search_phrase"), with: "Eliza")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> click(css("label", text: "Wedding"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(testid("card-Communications", text: "Elizabeth Taylor"))
    |> assert_has(testid("card-Communications", text: "taylor@example.com"))
    |> assert_has(testid("card-Communications", text: "(210) 111-1234"))
    |> add_missing_shoot_details()
    |> click(link("Picsello"))
    |> click(button("Leads"))
    |> assert_has(testid("card-Recent Leads"))
    |> click(button("View all"))
    |> assert_has(testid("job-row", count: 1))
  end

  feature "user creates lead with new client", %{session: session} do
    session
    |> click(button("Actions"))
    |> click(button("Create lead"))
    |> click(button("Add a new client"))
    |> fill_in(text_field("Client Name"), with: "Elizabeth Taylor")
    |> fill_in(text_field("Client Email"), with: "taylor-test@example.com")
    |> fill_in(text_field("Client Phone"), with: "(210) 111-1234")
    |> scroll_into_view(css("label", text: "Event"))
    |> click(css("label", text: "Event"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Event"))
    |> assert_has(testid("card-Communications", text: "Elizabeth Taylor"))
    |> assert_has(testid("card-Communications", text: "taylor-test@example.com"))
    |> assert_has(testid("card-Communications", text: "(210) 111-1234"))
    |> add_missing_shoot_details()
    |> click(link("Picsello"))
    |> click(button("Leads"))
    |> assert_has(testid("card-Recent Leads"))
    |> click(button("View all"))
    |> assert_has(testid("job-row", count: 1))
  end

  feature "user cannot create client with existing email", %{session: session} do
    session
    |> click(button("Actions"))
    |> click(button("Create lead"))
    |> click(button("Add a new client"))
    |> fill_in(text_field("Client Email"), with: "taylor@example.com")
    |> assert_has(css("label", text: "Client Email has already been taken"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user cannot create lead without job type", %{session: session} do
    session
    |> click(button("Actions"))
    |> click(button("Create lead"))
    |> fill_in(text_field("search_phrase"), with: "Eliza")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user creates lead with job type 'other'", %{session: session} do
    session
    |> click(button("Actions"))
    |> click(button("Create lead"))
    |> fill_in(text_field("search_phrase"), with: "Eliza")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> click(css("label", text: "Other"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Other"))
    |> assert_has(testid("card-Communications", text: "Elizabeth Taylor"))
    |> assert_has(testid("card-Communications", text: "taylor@example.com"))
    |> assert_has(testid("card-Communications", text: "(210) 111-1234"))
    |> add_missing_shoot_details()
    |> click(link("Picsello"))
    |> click(button("Leads"))
    |> assert_has(testid("card-Recent Leads"))
    |> click(button("View all"))
    |> assert_has(testid("job-row", count: 1))
  end

  defp add_missing_shoot_details(session) do
    session
    |> scroll_into_view(css("h2", text: "Shoot details"))
    |> click(css("button", text: "Add a package", at: 0))
    |> assert_has(css(".modal"))
    |> click(css("label", at: 0))
    |> click(button("Use template"))
    |> click(testid("shoot-card"))
    |> assert_has(css("h1", text: "Edit Shoot Details"))
    |> fill_in(css("#shoot_name"), with: "Shoot one")
    |> click(css("#shoot_duration_minutes"))
    |> click(css("option", text: "5 mins", at: 0))
    |> click(css("#shoot_location"))
    |> click(css("option", text: "In Studio", at: 0))
    |> click(css("#shoot-time"))
    |> click(css(".flatpickr-am-pm", at: 0))
    |> click(css("h1", text: "Edit Shoot Details"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
  end
end
