defmodule PicselloWeb.BrandLogoView do
  use PicselloWeb, :view

  alias Picsello.Accounts.User

  def render("show.html", assigns) do
    ~H"""
      <%= if @organization.profile.logo && @organization.profile.logo.url do %>
        <img src={@organization.profile.logo.url} height="40" style="height: 80px" />
      <% else %>
      <div class="flex items-center justify-center" height="40" style="height: 80px; padding-top: 30px">
        <div style={"background-color:#{@organization.profile.color};text-align:center;padding:18px 16px;font-weight:bold;color:white;font-size:17px;border-radius:90px;width:26px;"}>
          <%= User.initials(@user) %>
        </div>
      </div>
      <% end %>
    """
  end
end
