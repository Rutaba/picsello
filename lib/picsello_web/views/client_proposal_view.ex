defmodule PicselloWeb.ClientProposalView do

  use PicselloWeb, :view

  import PicselloWeb.Live.Profile.Shared,
    only: [
      photographer_logo: 1
    ]

  def render("show.html", assigns) do
    ~H"""
      <div class="">
        <div class="">
          <.photographer_logo organization={@organization} />
        </div>
        <hr class="border-gray-100 my-4">
        <h2 class="text-xs md:mt-12">
          <span class="capitalize"></span><%= @client_proposal.title %>
        </h2>

        <div class="grid md:grid-cols-2 gap-5">
          <div>
            <p class="text-xs">
              <br>
              Please note that your session will be considered officially booked once you accept the proposal, review and sign the contract, complete the questionnaire, and make payment.
              <br><br>
              Once your payment has been confirmed, your session is booked for you exclusively and any other client inquiries will be declined. You will receive a payment confirmation email and additional emails about your session leading up to the shoot.
              <br><br>
              <div class="text-xs">
                  <%= raw @client_proposal.message %>
              </div>
              <span class="text-xs"><%= @organization.name %></span>
            </p>
            <hr class="border-gray-100 my-4">
            <h3 class="uppercase text-base-250 text-xs">Have Questions?</h3>
            <span class="block mt-2 border text-xs w-max p-2 border-black"><%= @client_proposal.contact_button %></span>

          </div>
          <div>
            <h3 class="text-xs md:mr-20"> <%= @client_proposal.booking_panel_title %> </h3>
            <img src="/images/book_session_client_proposal.png" />
          </div>
        </div>
      </div>
    """
  end
end
