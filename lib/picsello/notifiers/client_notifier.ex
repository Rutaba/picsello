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

    deliver_email(message, to_email, %{
      button: %{url: BookingProposal.url(proposal.id), text: "View booking proposal"}
    })
  end

  def deliver_email(message, to_email, params \\ %{}) do
    job = message |> Repo.preload(:job) |> Map.get(:job)

    message
    |> message_params()
    |> Map.merge(params)
    |> deliver_transactional_email(to_email, job)
  end

  def deliver_balance_due_email(job, helpers) do
    with client <- job |> Repo.preload(:client) |> Map.get(:client),
         proposal <- BookingProposal.last_for_job(job.id),
         [preset | _] <- Picsello.EmailPresets.for(job, :balance_due),
         %{body_template: body, subject_template: subject} <-
           Picsello.EmailPresets.resolve_variables(preset, {job}, helpers) do
      %{subject: subject, body_text: HtmlSanitizeEx.strip_tags(body)}
      |> Picsello.Messages.insert_scheduled_message!(job)
      |> deliver_email(
        client.email,
        %{
          button: %{
            text: "Open invoice",
            url: BookingProposal.url(proposal.id)
          }
        }
      )
    end
  end

  def deliver_shipping_notification(event, order, helpers) do
    with %{gallery: gallery} <- order |> Repo.preload(gallery: :job),
         [preset | _] <- Picsello.EmailPresets.for(gallery, :gallery_shipping_to_client),
         %{shipping_info: [%{tracking_url: tracking_url} | _]} <- event,
         %{body_template: body, subject_template: subject} <-
           Picsello.EmailPresets.resolve_variables(preset, {gallery, order}, helpers) do
      deliver_transactional_email(
        %{
          subject: subject,
          headline: subject,
          body: body,
          button: %{
            text: "Track shipping",
            url: tracking_url
          }
        },
        order.delivery_info.email,
        gallery.job
      )
    end
  end

  def deliver_payment_schedule_confirmation(job, payment_schedule, helpers) do
    with client <- job |> Repo.preload(:client) |> Map.get(:client),
         [preset | _] <- Picsello.EmailPresets.for(job, :payment_confirmation_client),
         %{body_template: body, subject_template: subject} <-
           Picsello.EmailPresets.resolve_variables(preset, {job, payment_schedule}, helpers) do
      deliver_transactional_email(
        %{subject: subject, headline: subject, body: body},
        client.email,
        job
      )
    end
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
      for(product <- Cart.preload_products(order).products) do
        %{
          item_name: Cart.product_name(product),
          item_quantity: Cart.product_quantity(product),
          item_price: Cart.Product.charged_price(product),
          item_is_digital: false
        }
      end

    digitals =
      for(digital <- order.digitals) do
        %{
          item_name: "Digital Download",
          item_quantity: 1,
          item_price: Cart.price_display(digital),
          item_is_digital: true
        }
      end

    opts = [
      client_name: client_name,
      contains_digital: digitals != [],
      contains_physical: products != [],
      gallery_url: helpers.gallery_url(gallery),
      logo_url: Picsello.Profiles.logo_url(organization),
      order_address: products != [] && order_address(client_name, address),
      order_date: helpers.strftime(time_zone, order.placed_at, "%-m/%-d/%y"),
      order_items: products ++ digitals,
      order_number: Picsello.Cart.Order.number(order),
      order_shipping: Money.new(0),
      order_subtotal: Order.total_cost(order),
      order_total: Order.total_cost(order),
      order_url: helpers.order_url(gallery, order),
      subject: "#{organization.name} - order ##{Picsello.Cart.Order.number(order)}"
    ]

    sendgrid_template(:order_confirmation_template, opts)
    |> to({client_name, to_email})
    |> from({organization.name, "noreply@picsello.com"})
    |> deliver_later()
  end

  defp message_params(message) do
    %{
      subject: message.subject,
      headline: message.subject,
      body: message |> body_html
    }
  end

  defp body_html(%{body_html: nil, body_text: body_text}),
    do: body_text |> Phoenix.HTML.Format.text_to_html() |> Phoenix.HTML.safe_to_string()

  defp body_html(%{body_html: body_html}), do: body_html

  defp order_address(_, nil), do: nil

  defp order_address(name, %{state: state, city: city, zip: zip, addr1: addr1, addr2: addr2}),
    do:
      for(
        "" <> line <- [name, addr1, addr2, "#{city}, #{state} #{zip}"],
        into: "",
        do: "<p>#{line}</p>"
      )

  defp deliver_transactional_email(params, to_email, job) do
    job = job |> Repo.preload(client: [organization: :user])
    %{organization: organization} = job.client

    params =
      Map.merge(
        %{
          logo_url: if(organization.profile.logo, do: organization.profile.logo.url),
          organization_name: organization.name,
          email_signature: email_signature(organization)
        },
        params
      )

    reply_to = Job.email_address(job)
    from_display = organization.name

    :client_transactional_template
    |> sendgrid_template(params)
    |> put_header("reply-to", "#{from_display} <#{reply_to}>")
    |> from({from_display, "noreply@picsello.com"})
    |> to(to_email)
    |> deliver_later()
  end
end
