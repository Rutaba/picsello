defmodule PicselloWeb.EmailSignatureView do
  use PicselloWeb, :view
  import PicselloWeb.LiveHelpers, only: [get_brand_link_icon: 1, testid: 1]

  alias Picsello.Accounts.User
  alias Picsello.Profiles

  def render("show.html", assigns) do
    {first_brand_link, remaining_brand_links} =
      Profiles.get_brand_links_by_organization(assigns.organization)
      |> Enum.filter(&(&1.use_publicly? && &1.active?))
      |> List.pop_at(0)

    assigns = Enum.into(assigns, %{first_brand_link: first_brand_link, remaining_brand_links: remaining_brand_links})

    ~H"""
    <table style="font-family: sans-serif, Arial;line-height:22px;border-collapse: collapse;" border="0" cellpadding="0" cellspacing="0" width="100%" role="presentation">
      <tr style="border-collapse:collapse;" border="0" cellpadding="0" cellspacing="0" width="100%">
        <td style="color:#1F1C1E;border:0px;font-weight:bold;font-size:18px;border-collapse:collapse;padding:20px 0;" border="0" cellpadding="0" cellspacing="0" width="100%">--</td>
      </tr>
      <tr style="border-collapse:collapse;" border="0" cellpadding="0" cellspacing="0" width="100%">
        <td style="border-collapse:collapse;padding-bottom:10px;" border="0" cellpadding="0" cellspacing="0" width="100%">
          <%= if @organization.profile.logo && @organization.profile.logo.url do %>
            <img src={@organization.profile.logo.url} height="40" style="height: 40px" />
          <% else %>
            <div style={"background-color:#{@organization.profile.color};text-align:center;padding:18px 16px;font-weight:bold;color:white;font-size:17px;border-radius:90px;width:26px;"}><%= User.initials(@user) %></div>
          <% end %>
        </td>
      </tr>
      <tr style="border-collapse:collapse;" border="0" cellpadding="0" cellspacing="0" width="100%">
        <td style="color:#1F1C1E;border:0px;font-weight:bold;font-size:18px;border-collapse:collapse;" border="0" cellpadding="0" cellspacing="0" width="100%"><%= @organization.name %></td>
      </tr>
      <%= if @organization.email_signature.show_phone && @user.onboarding.phone do %>
        <tr style="border-collapse:collapse;" border="0" cellpadding="0" cellspacing="0" width="100%">
          <td style={"color:#{@organization.profile.color};padding-top:10px;padding-bottom:10px;border:0px;border-collapse:collapse;font-size:18px;"} border="0" cellpadding="0" cellspacing="0" width="100%">
            <a href="tel:5097284377" style="text-decoration:none;color:#1F1C1E;"><%= @user.onboarding.phone %></a>
          </td>
        </tr>
      <% end %>
      <%= if @organization.email_signature.content do %>
        <tr style="border-collapse:collapse;" border="0" cellpadding="0" cellspacing="0" width="100%">
          <td style="border-collapse:collapse;" border="0" cellpadding="0" cellspacing="0" width="100%">
            <%= raw @organization.email_signature.content %>
          </td>
        </tr>
      <% end %>
    </table>
    <div style="margin-top:15px;display:flex;flex-direction:column;">
      <div style="display:flex;flex-wrap:wrap;">
          <%= case @first_brand_link do %>
            <% nil -> %>
            <% %{link: link, link_id: link_id} -> %>
              <.brand_link link={link} link_id={link_id} style="padding:16px 16px 16px 0px;"></.brand_link>
          <% end %>
          <%= for %{link: link, link_id: link_id} <- @remaining_brand_links do %>
            <.brand_link link={link} link_id={link_id} style="padding:16px;"><span style="border-left:1px solid #898989;height:15px"></span></.brand_link>
          <% end %>
        </div>
      </div>
    """
  end

  defp brand_link(assigns) do
    ~H"""
    <div {testid("marketing-links")} style="display:flex;align-items:center;margin-bottom:16px;">
      <a style="display:flex;align-items:center;justify-content:center;" href={@link} target="_blank" rel="noopener noreferrer">
        <%= render_slot(@inner_block) %>
        <div style={"display:flex;align-items:center;justify-content:center;width:24px;height:24px;flex-shrink:0;#{@style}"}>
          <span style="fill:currentColor;color:#898989;">
            <img src={"#{PicselloWeb.Endpoint.static_url()}/images/social_icons/#{get_brand_link_icon(@link_id)}.png"} />
          </span>
        </div>
      </a>
    </div>
    """
  end
end
