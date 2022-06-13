defmodule Picsello.MarketingTest do
  use Picsello.DataCase, async: true
  alias Picsello.Marketing

  describe "send_campaign_mail/1" do
    test "send emails" do
      color = Picsello.Profiles.Profile.colors() |> hd

      user =
        insert(:user,
          name: "John Jack",
          email: "john@example.com",
          organization: %{name: "Photo 1", slug: "photo-1", profile: %{color: color}}
        )

      client = insert(:client, user: user, email: "client@example.com")
      campaign = insert(:campaign, user: user, body_html: "<p>body</p>")
      campaign_client = insert(:campaign_client, campaign: campaign, client: client)

      pid = self()

      Tesla.Mock.mock(fn %{method: :post, body: body} ->
        send(pid, :post)

        assert %{
                 "asm" => %{"group_id" => 123},
                 "from" => %{"email" => "noreply@picsello.com", "name" => "Photo 1"},
                 "reply_to" => %{"email" => "john@example.com", "name" => "Photo 1"},
                 "personalizations" => [
                   %{
                     "to" => [%{"email" => "client@example.com"}],
                     "dynamic_template_data" => %{
                       "initials" => "JJ",
                       "organization_name" => "Photo 1",
                       "logo_url" => nil,
                       "color" => ^color,
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
      assert_received :post

      campaign_client = campaign_client |> Repo.reload()

      assert campaign_client.delivered_at != nil

      # calling it again to make sure it doesn't make another API call
      Marketing.send_campaign_mail(campaign.id)
      refute_received :post
    end
  end
end
