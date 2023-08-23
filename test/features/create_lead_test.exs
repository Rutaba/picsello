defmodule Picsello.CreateLeadTest do
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

    [client: client]
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
    |> fill_in(text_field("Client Email"), with: "taylor_test@example.com")
    |> fill_in(text_field("Client Phone"), with: "(210) 111-1234")
    |> scroll_into_view(css("label", text: "Event"))
    |> click(css("label", text: "Event"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Event"))
    |> assert_has(testid("card-Communications", text: "Elizabeth Taylor"))
    |> assert_has(testid("card-Communications", text: "taylor_test@example.com"))
    |> assert_has(testid("card-Communications", text: "(210) 111-1234"))
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
    |> click(link("Picsello"))
    |> click(button("Leads"))
    |> assert_has(testid("card-Recent Leads"))
    |> click(button("View all"))
    |> assert_has(testid("job-row", count: 1))
  end
end
