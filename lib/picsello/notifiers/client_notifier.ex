defmodule Picsello.Notifiers.ClientNotifier do
  @moduledoc false
  use Picsello.Notifiers
  alias Picsello.{BookingProposal, Repo, Job}

  @doc """
  Deliver booking proposal email.
  """
  def deliver_booking_proposal(message, to_email) do
    proposal = BookingProposal.last_for_job(message.job_id)

    message
    |> client_message_to_email(:booking_proposal_template, url: BookingProposal.url(proposal.id))
    |> to(to_email)
    |> deliver_later()
  end

  def deliver_email(message, to_email) do
    message |> client_message_to_email(:email_template) |> to(to_email) |> deliver_later()
  end

  defp client_message_to_email(message, template_name, opts \\ []) do
    job = message |> Repo.preload(job: [client: [organization: :user]]) |> Map.get(:job)
    %{organization: organization} = job.client

    opts =
      Keyword.merge(
        [
          subject: message.subject,
          body_html: message |> body_html,
          body_text: message.body_text,
          email_signature: email_signature(organization),
          color: organization.profile.color
        ],
        opts
      )

    reply_to = Job.email_address(job)
    from_display = job.client.organization.name

    template_name
    |> sendgrid_template(opts)
    |> cc(message.cc_email)
    |> put_header("reply-to", "#{from_display} <#{reply_to}>")
    |> from({from_display, "noreply@picsello.com"})
  end

  defp body_html(%{body_html: nil, body_text: body_text}),
    do: body_text |> Phoenix.HTML.Format.text_to_html() |> Phoenix.HTML.safe_to_string()

  defp body_html(%{body_html: body_html}), do: body_html

  defp email_signature(organization) do
    Phoenix.View.render_to_string(PicselloWeb.EmailSignatureView, "show.html",
      organization: organization,
      user: organization.user
    )
  end
end
