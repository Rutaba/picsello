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
          <%= raw Phoenix.View.render_to_string(PicselloWeb.ClientProposalView, "show.html", organization: @organization, user: @user, client_proposal: client_proposal(@organization)) %>
        </div>
      </div>
    </div>
    """
  end

  def default_client_proposal(organization) do
    name = if organization, do: organization.name, else: "Us"

    %{
      title: "Welcome",
      booking_panel_title: "Here's how to officially book your photo session:",
      message:
        "<p>Let's get your shoot booked!</p><p><br></p><p>We are so excited to work with you!</p><p><br></p>",
      contact_button: "Message #{name}"
    }
  end

  def client_proposal(%{client_proposal: nil} = organization),
    do: default_client_proposal(organization)

  def client_proposal(%{client_proposal: client_proposal}), do: client_proposal
end
