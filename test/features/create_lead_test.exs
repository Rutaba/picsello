defmodule Picsello.CreateLeadTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  @client_name "John Doe"
  @client_email "doe@example.com"
  @client_phone "(210) 111-5678"

  setup %{session: session, user: user} do
    client =
      insert(:client,
        user: user,
        name: "Elizabeth Taylor",
        phone: "taylor@example.com",
        email: "(210) 111-1234"
      )

    [client: client, session: session, user: user]
  end

  feature "user creates lead with existing client", %{session: session, client: client} do
    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("search_phrase"), with: "Eliza")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> click(css("label", text: "Wedding"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "#{client.name} Wedding"))
    |> assert_has(testid("card-Communications", text: client.name))
    |> assert_has(testid("card-Communications", text: client.email))
    |> assert_has(testid("card-Communications", text: client.phone))
    |> click(link("Picsello"))
    |> find(testid("leads-card"))
    |> assert_text("1 pending lead")
  end

  feature "user creates lead with new client", %{session: session} do
    session
    |> click(button("Create a lead"))
    |> click(button("Add a new client"))
    |> fill_in(text_field("Client Name"), with: @client_name)
    |> fill_in(text_field("Client Email"), with: @client_email)
    |> fill_in(text_field("Client Phone"), with: @client_phone)
    |> scroll_into_view(css("label", text: "Event"))
    |> click(css("label", text: "Event"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "#{@client_name} Event"))
    |> assert_has(testid("card-Communications", text: @client_name))
    |> assert_has(testid("card-Communications", text: @client_email))
    |> assert_has(testid("card-Communications", text: @client_phone))
    |> click(link("Picsello"))
    |> find(testid("leads-card"))
    |> assert_text("1 pending lead")
  end

  feature "user cannot create client with existing email", %{session: session, client: client} do
    session
    |> click(button("Create a lead"))
    |> click(button("Add a new client"))
    |> fill_in(text_field("Client Email"), with: client.email)
    |> assert_has(css("label", text: "Client Email already exists"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user cannot create lead without job type", %{session: session, client: _client} do
    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("search_phrase"), with: "Eliza")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user creates lead with job type 'other'", %{session: session, client: client} do
    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("search_phrase"), with: "Eliza")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> click(css("label", text: "Other"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "#{client.name} Other"))
    |> click(link("Picsello"))
    |> find(testid("leads-card"))
    |> assert_text("1 pending lead")
  end
end
