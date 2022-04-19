defmodule PicselloWeb.EmailSignatureView do
  use PicselloWeb, :view
  alias Picsello.Accounts.User

  def render("show.html", assigns) do
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
    """
  end
end
