defmodule Picsello.Notifiers.ClientNotifier do
  @moduledoc false
  use Picsello.Notifiers

  @doc """
  Deliver booking proposal email.
  """
  def deliver_booking_proposal(message, to_email, url) do
    sendgrid_template(:booking_proposal_template,
      url: url,
      subject: message.subject,
      body_html: message.body_html,
      body_text: message.body_text
    )
    |> to(to_email)
    |> cc(message.cc_email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end
end
