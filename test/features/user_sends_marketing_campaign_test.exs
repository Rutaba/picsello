defmodule Picsello.UserSendsMarketingCampaignTest do
  @moduledoc false
  use Picsello.FeatureCase, async: false
  use Oban.Testing, repo: Picsello.Repo
  alias Picsello.{Repo, Campaign}

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    insert(:lead, user: user)
    insert(:client, user: user)

    Tesla.Mock.mock_global(fn
      %{method: :get} ->
        body = %{"versions" => [%{"html_content" => "TEMPLATE_PREVIEW", "active" => 1}]}
        %Tesla.Env{status: 200, body: body}
    end)

    [session: session]
  end

  feature "sends campaign to new clients", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> click(button("Create an email"))
    |> assert_text("Unassigned clients (1)")
    |> assert_text("All clients (2)")
    |> fill_in(text_field("Subject"), with: "My subject")
    |> fill_in_quill("This is the body")
    |> click(button("Review"))
    |> focus_frame(css("iframe#template-preview"))
    |> assert_text("TEMPLATE_PREVIEW")
    |> focus_parent_frame()
    |> assert_text("Recipient list: 1 client")
    |> click(button("Send"))
    |> assert_flash(:success, text: "Promotional Email sent")
    |> assert_text("MOST RECENT")
    |> assert_text("My subject")
    |> assert_text("to 1 client")

    campaign = Repo.get_by(Campaign, subject: "My subject")
    assert_enqueued(worker: Picsello.Workers.SendCampaign, args: %{id: campaign.id})

    session
    |> click(testid("campaign-item"))
    |> within_modal(&assert_text(&1, "My subject"))
    |> within_modal(&assert_text(&1, "Recipient list: 1 client"))
    |> focus_frame(css("iframe#template-preview"))
    |> assert_text("TEMPLATE_PREVIEW")
  end

  feature "sends campaign to all clients", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> click(button("Create an email"))
    |> fill_in(text_field("Subject"), with: "My subject")
    |> click(css("label", text: "All clients (2)"))
    |> click(button("Review"))
    |> assert_text("Review email")
    |> click(button("Send"))
    |> assert_flash(:success, text: "Promotional Email sent")
    |> assert_text("MOST RECENT")
    |> assert_text("My subject")
    |> assert_text("to 2 clients")

    campaign = Repo.get_by(Campaign, subject: "My subject")
    assert_enqueued(worker: Picsello.Workers.SendCampaign, args: %{id: campaign.id})
  end
end
