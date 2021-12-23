defmodule Picsello.MarketingTest do
  use Picsello.DataCase, async: true
  alias Picsello.Marketing

  describe "send_campaign_mail/1" do
    test "send emails" do
      user =
        insert(:user,
          name: "John Jack",
          organization: %{name: "Photo 1", slug: "photo-1", profile: %{color: "#3AE7C7"}}
        )

      client = insert(:client, user: user, email: "client@example.com")
      campaign = insert(:campaign, user: user, body_html: "<p>body</p>")
      campaign_client = insert(:campaign_client, campaign: campaign, client: client)

      Tesla.Mock.mock(fn %{method: :post, body: body} ->
        assert %{
                 "asm" => %{"group_id" => 123},
                 "from" => %{"email" => "noreply@picsello.com", "name" => "Photo 1"},
                 "personalizations" => [
                   %{
                     "to" => [%{"email" => "client@example.com"}],
                     "dynamic_template_data" => %{
                       "initials" => "JJ",
                       "color" => "#3AE7C7",
                       "button_url" => "http://localhost:4002/photographer/photo-1",
                       "content" => "<p>body</p>"
                     }
                   }
                 ],
                 "template_id" => "marketing-xyz"
               } = Jason.decode!(body)

        %Tesla.Env{
          status: 200,
          body: %{}
        }
      end)

      Marketing.send_campaign_mail(campaign.id)

      campaign_client = campaign_client |> Repo.reload()

      assert campaign_client.delivered_at != nil
    end
  end
end
