defmodule Picsello.Marketing do
  @moduledoc "context module for campaigns"
  import Ecto.Query, only: [from: 2]

  alias Picsello.{
    Repo,
    Campaign,
    CampaignClient,
    Client,
    Job,
    Profiles,
    Accounts.User
  }

  def new_campaign_changeset(attrs, organization_id) do
    attrs
    |> Map.put("organization_id", organization_id)
    |> Campaign.changeset()
  end

  def save_new_campaign(attrs, organization_id) do
    changeset = new_campaign_changeset(attrs, organization_id)

    segment_type = Ecto.Changeset.get_field(changeset, :segment_type)
    clients = clients(segment_type, organization_id)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:campaign, changeset)
    |> Ecto.Multi.insert_all(:campaign_clients, CampaignClient, fn %{campaign: campaign} ->
      inserted_at = DateTime.utc_now() |> DateTime.truncate(:second)
      updated_at = DateTime.utc_now() |> DateTime.truncate(:second)

      clients
      |> Enum.map(fn client ->
        %{
          client_id: client.id,
          campaign_id: campaign.id,
          inserted_at: inserted_at,
          updated_at: updated_at
        }
      end)
    end)
    |> Oban.insert(:campaign_email, fn %{campaign: campaign} ->
      %{id: campaign.id}
      |> Picsello.Workers.SendCampaign.new()
    end)
    |> Repo.transaction()
  end

  def recent_campaigns(organization_id, limit \\ 4) do
    from(c in Campaign,
      left_join: cc in CampaignClient,
      on: cc.campaign_id == c.id,
      where: c.organization_id == ^organization_id,
      order_by: [desc: c.inserted_at],
      limit: ^limit,
      group_by: c.id,
      select: %{
        subject: c.subject,
        inserted_at: c.inserted_at,
        clients_count: count(cc.id)
      }
    )
    |> Repo.all()
  end

  def clients(segment_type, organization_id) do
    segment_type
    |> clients_query(organization_id)
    |> Repo.all()
  end

  def segments_count(organization_id) do
    ["all", "new"]
    |> Enum.into(%{}, fn type ->
      {type, type |> clients_query(organization_id) |> Repo.aggregate(:count)}
    end)
  end

  defp clients_query("new", organization_id) do
    from(c in Client,
      left_join: j in Job,
      on: j.client_id == c.id,
      where:
        c.organization_id == ^organization_id and
          is_nil(j.id),
      select: %{id: c.id, email: c.email}
    )
  end

  defp clients_query("all", organization_id) do
    from(c in Client,
      where: c.organization_id == ^organization_id,
      select: %{id: c.id, email: c.email}
    )
  end

  def template_preview(user, body_html) do
    {:ok, %{body: body}} = SendgridClient.marketing_template_id() |> SendgridClient.get_template()

    template =
      body
      |> Map.get("versions")
      |> Enum.find(&(Map.get(&1, "active") == 1))
      |> Map.get("html_content")

    Mustache.render(template, template_variables(user, body_html))
  end

  defp template_variables(user, body_html) do
    %{profile: profile} = organization = Profiles.find_organization_by(user: user)

    %{
      initials: User.initials(user),
      color: profile.color,
      button_url: Profiles.public_url(organization),
      content: body_html
    }
  end

  def send_campaign_mail(campaign_id) do
    campaign = Campaign |> Repo.get(campaign_id) |> Repo.preload(organization: :user)
    %{organization: organization} = campaign

    template_data =
      template_variables(organization.user, campaign.body_html)
      |> Map.put(:subject, campaign.subject)

    all_clients =
      from(c in Client,
        join: cc in CampaignClient,
        on: cc.client_id == c.id,
        where: cc.campaign_id == ^campaign_id and is_nil(cc.delivered_at),
        select: %{id: c.id, email: c.email}
      )
      |> Repo.all()

    # chunk clients since Sendgrid limits 1000 personalizations per request
    all_clients
    |> Enum.chunk_every(1000)
    |> Enum.each(fn clients ->
      body = %{
        from: %{email: "noreply@picsello.com", name: organization.name},
        personalizations:
          Enum.map(clients, fn client ->
            %{
              to: [%{email: client.email}],
              dynamic_template_data: template_data
            }
          end),
        template_id: SendgridClient.marketing_template_id(),
        asm: %{
          group_id: SendgridClient.marketing_unsubscribe_id()
        }
      }

      {:ok, _} = SendgridClient.send_mail(body)

      client_ids = Enum.map(clients, & &1.id)

      from(cc in CampaignClient,
        where: cc.campaign_id == ^campaign.id and cc.client_id in ^client_ids
      )
      |> Repo.update_all(set: [delivered_at: DateTime.utc_now() |> DateTime.truncate(:second)])
    end)
  end
end
