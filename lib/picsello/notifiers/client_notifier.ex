defmodule Picsello.Notifiers.ClientNotifier do
  @moduledoc false
  use Picsello.Notifiers
  alias Picsello.{BookingProposal, Repo, Job, Cart}
  alias Cart.Order

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

  def deliver_order_confirmation(
        %{
          gallery: %{job: %{client: %{organization: organization}}} = gallery,
          delivery_info: %{name: client_name, address: address, email: to_email}
        } = order,
        helpers
      ) do
    %{user: %{time_zone: time_zone}} = Repo.preload(organization, :user)

    products =
      for(product <- order |> Cart.preload_products() |> Map.get(:products)) do
        %{
          item_name: Cart.product_name(product),
          item_quantity: Cart.product_quantity(product),
          item_price: product.price,
          item_is_digital: false
        }
      end

    digitals =
      for(digital <- order.digitals) do
        %{
          item_name: "Digital Download",
          item_quantity: 1,
          item_price: digital.price,
          item_is_digital: true
        }
      end

    opts = [
      subject: "#{organization.name} - order ##{Picsello.Cart.Order.number(order)}",
      logo_url: Picsello.Profiles.logo_url(organization),
      client_name: client_name,
      gallery_url: helpers.gallery_url(gallery),
      order_url: helpers.order_url(gallery, order),
      order_number: Picsello.Cart.Order.number(order),
      order_date: helpers.strftime(time_zone, order.placed_at, "%-m/%-d/%y"),
      order_subtotal: Order.subtotal_cost(order),
      order_shipping: Order.shipping_cost(order),
      order_total: Order.total_cost(order),
      order_address: order_address(client_name, address),
      order_items: products ++ digitals
    ]

    sendgrid_template(:order_confirmation_template, opts)
    |> to({client_name, to_email})
    |> from({organization.name, "noreply@picsello.com"})
    |> deliver_later()
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

  defp order_address(_, nil), do: nil

  defp order_address(name, %{state: state, city: city, zip: zip, addr1: addr1, addr2: addr2}),
    do:
      for(
        "" <> line <- [name, addr1, addr2, "#{city}, #{state} #{zip}"],
        into: "",
        do: "<p>#{line}</p>"
      )
end
