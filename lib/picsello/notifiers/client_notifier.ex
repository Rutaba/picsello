defmodule Picsello.Notifiers.ClientNotifier do
  @moduledoc false
  use Picsello.Notifiers

  @doc """
  Deliver booking proposal email.
  """
  def deliver_booking_proposal(message, to_email) do
    sendgrid_template(:booking_proposal_template,
      url: Picsello.BookingProposal.url(message.proposal_id),
      subject: message.subject,
      body_html: message |> body_html,
      body_text: message.body_text
    )
    |> to(to_email)
    |> cc(message.cc_email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  defp body_html(%{body_html: nil, body_text: body_text}),
    do: body_text |> Phoenix.HTML.Format.text_to_html() |> Phoenix.HTML.safe_to_string()

  defp body_html(%{body_html: body_html}), do: body_html
end
