defmodule PicselloWeb.Live.Brand.Shared do
  @moduledoc false

  use Phoenix.Component
  use Phoenix.HTML

  def brand_logo_preview(assigns) do
    ~H"""
    <div>
      <%= if @organization.profile.logo && @organization.profile.logo.url do %>
        <div class="input-label mb-4">Logo Preview</div>
      <% else %>
        <div class="input-label mb-4">Logo Preview (showing default)</div>
      <% end %>
      <div class="shadow-2xl rounded-lg flex items-center justify-center raw_html h-full p-10">
        <div>
          <%= raw Phoenix.View.render_to_string(PicselloWeb.BrandLogoView, "show.html", organization: @organization, user: @user) %>
        </div>
      </div>
    </div>
    """
  end

  def email_signature_preview(assigns) do
    ~H"""
    <div>
      <div class="input-label mb-4">Signature Preview</div>
      <div class="shadow-2xl rounded-lg px-6 pb-6 raw_html">
        <div>
          <%= raw Phoenix.View.render_to_string(PicselloWeb.EmailSignatureView, "show.html", organization: @organization, user: @user) %>
        </div>
      </div>
    </div>
    """
  end

  def client_proposal_preview(assigns) do
    ~H"""
    <div>
      <div class="input-label mb-4">Client Proposal Preview</div>
      <div class="shadow-2xl rounded-lg px-6 pb-6 raw_html">
        <div>
          <%= raw Phoenix.View.render_to_string(PicselloWeb.ClientProposalView, "show.html", organization: @organization, user: @user, default_client_proposal_params: @default_client_proposal_params) %>
        </div>
      </div>
    </div>
    """
  end
end
