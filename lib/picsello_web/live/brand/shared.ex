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
        "Please note that your session will be considered officially booked once you accept the proposal, review and sign the contract, complete the questionnaire, and make payment.
        <br>
        Once your payment has been confirmed, your session is booked for you exclusively and any other client inquiries will be declined. You will receive a payment confirmation email and additional emails about your session leading up to the shoot.
        <br>
        Let's get your shoot booked!
        <br>
        We are so excited to work with you!",
      contact_button: "Message #{name}"
    }
  end

  def client_proposal(%{client_proposal: nil} = organization),
    do: default_client_proposal(organization)

  def client_proposal(%{client_proposal: client_proposal}), do: client_proposal
end
