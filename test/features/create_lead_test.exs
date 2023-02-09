defmodule Picsello.CreateLeadTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    client =
      insert(:client,
        user: user,
        name: "Elizabeth Taylor",
        phone: "taylor@example.com",
        email: "(210) 111-1234"
      )

    [client: client]
  end

  feature "user creates lead with existing client", %{session: session} do
    session
    |> click(button("Create a lead"))
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
    |> find(testid("leads-card"))
    |> assert_text("1 pending lead")
  end

  feature "user creates lead with new client", %{session: session} do
    session
    |> click(button("Create a lead"))
    |> click(button("Add a new client"))
    |> fill_in(text_field("Client Name"), with: "Elizabeth Taylor")
    |> fill_in(text_field("Client Email"), with: "taylor@example.com")
    |> fill_in(text_field("Client Phone"), with: "(210) 111-1234")
    |> scroll_into_view(css("label", text: "Event"))
    |> click(css("label", text: "Event"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Event"))
    |> assert_has(testid("card-Communications", text: "Elizabeth Taylor"))
    |> assert_has(testid("card-Communications", text: "taylor@example.com"))
    |> assert_has(testid("card-Communications", text: "(210) 111-1234"))
    |> click(link("Picsello"))
    |> find(testid("leads-card"))
    |> assert_text("1 pending lead")
  end

  feature "user cannot create client with existing email", %{session: session, user: user} do
    insert(:client,
      user: user,
      name: "Elizabeth Taylor",
      phone: "(210) 111-1234",
      email: "taylor@example.com"
    )

    session
    |> click(button("Create a lead"))
    |> click(button("Add a new client"))
    |> fill_in(text_field("Client Email"), with: "taylor@example.com")
    |> assert_has(css("label", text: "Client Email has already been taken"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user cannot create lead without job type", %{session: session, user: user} do
    insert(:client,
      user: user,
      name: "Elizabeth Taylor",
      phone: "(210) 111-1234",
      email: "taylor@example.com"
    )

    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("search_phrase"), with: "Eliza")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user creates lead with job type 'other'", %{session: session, user: user} do
    insert(:client,
      user: user,
      name: "Elizabeth Taylor",
      phone: "(210) 111-1234",
      email: "taylor@example.com"
    )

    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("search_phrase"), with: "Eliza")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> click(css("label", text: "Other"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Other"))
    |> click(link("Picsello"))
    |> find(testid("leads-card"))
    |> assert_text("1 pending lead")
  end
end
