defmodule Picsello.Notifiers.ClientNotifier do
  @moduledoc false
  use Picsello.Notifiers
  import Picsello.Messages, only: [get_emails: 2]

  alias Picsello.{BookingProposal, Job, Repo, Cart, Messages, Galleries.Gallery}
  alias Cart.Order
  require Logger

  @doc """
  Deliver booking proposal email.
  """
  def deliver_booking_proposal(message, to_email) do
    proposal = BookingProposal.last_for_job(message.job_id)

    deliver_email(message, %{"to" => to_email}, %{
      button: %{url: BookingProposal.url(proposal.id), text: "View booking proposal"}
    })
  end

  @doc """
  recipients data structure can be:
  %{
    "to" => [example@gmail.com, example2@gmail.com],
    "cc" => [cc@gmail.com, cc@gmail.com],
    "bcc" => [bcc@gmail.com, bcc@gmail.com],
  }
  """
  def deliver_email(message, recipients, params \\ %{}) do
    message = message |> Repo.preload([:job, :clients], force: true)

    IO.inspect recipients, label: "recipients"
    IO.inspect message, label: "message"

    message
    |> message_params()
    |> Map.merge(params)
    |> deliver_transactional_email(recipients, if(message.job, do: message.job, else: message.clients))
  end

  def deliver_payment_made(proposal) do
    %{job: %{client: %{organization: organization} = client} = job} =
      proposal |> Repo.preload(job: [client: [organization: :user]])

    %{
      subject: "Thank you for your payment",
      body: """
      <p>#{organization.name} has recieved #{Picsello.PaymentSchedules.paid_price(job) |> Money.to_string(fractional_unit: false)} towards #{Picsello.Job.name(job)}. Your remaining balance for #{Picsello.Job.name(job)} is #{Picsello.PaymentSchedules.owed_price(job) |> Money.to_string(fractional_unit: false)}</p>
      <p>Your can pay either through: </p>
      <p>  &bull; check or cash to your photographer directly using the invoice found here</p>
      <p>  &bull; via card here through your photographer's secure payment portal</p>
      <p>We can't wait to work with you!</p>
      <p>CTA: <a href="#{BookingProposal.url(proposal.id)}">View Booking </a></p>
      """
    }
    |> deliver_transactional_email(%{"to" => client.email})
  end

  def deliver_payment_due(proposal) do
    %{job: %{client: %{organization: organization} = client} = job} =
      proposal |> Repo.preload(job: [client: [organization: :user]])

    %{
      subject: "You have an upcoming payment",
      body: """
      <p>You have an upcoming payment for #{organization.name}. Your remaining balance for #{Picsello.Job.name(job)} is #{Picsello.PaymentSchedules.owed_price(job) |> Money.to_string(fractional_unit: false)}</p>
      <p>Your can pay either through: </p>
      <p>  &bull; check or cash to your photographer directly using the invoice found here</p>
      <p>  &bull; via card here through your photographer's secure payment portal</p>
      <p>We can't wait to work with you!</p>
      <p>CTA: <a href="#{BookingProposal.url(proposal.id)}"> View Booking </a></p>
      """
    }
    |> deliver_transactional_email(%{"to" => client.email})
  end

  def deliver_paying_by_invoice(proposal) do
    %{job: %{client: %{organization: organization} = client} = job} =
      proposal |> Repo.preload(job: [client: [organization: :user]])

    %{
      subject: "Cash or check payment",
      body: """
      <p>You said you will pay #{organization.name} for #{Picsello.Job.name(job)} through a cash or check for the following #{Picsello.PaymentSchedules.owed_price(job) |> Money.to_string(fractional_unit: false)} it is due on #{Picsello.PaymentSchedules.remainder_due_on(job) |> Calendar.strftime("%B %d, %Y")}.</p>
      <p>Please arrange payment with me by replying to this email</p>
      <p>We can't wait to work with you!</p>
      <p>CTA: <a href="#{PicselloWeb.Helpers.invoice_url(job.id, proposal.id)}"> Download PDF </a></p>
      """
    }
    |> deliver_transactional_email(%{"to" => client.email})
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
        %{"to" => order.delivery_info.email},
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
        %{"to" => client.email},
        job
      )
    end
  end

  def deliver_balance_due_email(job, helpers) do
    with client <- job |> Repo.preload(:client) |> Map.get(:client),
         proposal <- BookingProposal.last_for_job(job.id),
         false <- is_nil(proposal),
         [preset | _] <- Picsello.EmailPresets.for(job, :balance_due),
         %{body_template: body, subject_template: subject} <-
           Picsello.EmailPresets.resolve_variables(preset, {job}, helpers) do
      Logger.warn("job: #{inspect(job.id)}")
      Logger.warn("Proposal: #{inspect(proposal)}")

      %{subject: subject, body_text: HtmlSanitizeEx.strip_tags(body)}
      |> Picsello.Messages.insert_scheduled_message!(job)
      |> deliver_email(
        %{"to" => client.email},
        %{
          button: %{
            text: "Open invoice",
            url: BookingProposal.url(proposal.id)
          }
        }
      )
    else
      error ->
        Logger.warn("job: #{inspect(job.id)}")
        Logger.warn("something went wrong: #{inspect(error)}")
        error
    end
  end

  def deliver_order_confirmation(
        %{
          gallery:
            %{
              job: %{
                client: %{organization: %{user: %{time_zone: "" <> time_zone}} = organization}
              }
            } = gallery,
          delivery_info: %{name: client_name, address: address, email: to_email},
          album: album
        } = order,
        helpers
      ) do
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
      order_url:
        if(order.album_id,
          do: helpers.proofing_album_selections_url(album, order),
          else: helpers.order_url(gallery, order)
        ),
      subject: "#{organization.name} - order ##{Picsello.Cart.Order.number(order)}"
    ]

    order.album_id
    |> may_be_proofing_album_selection()
    |> sendgrid_template(opts)
    |> to({client_name, to_email})
    |> from({organization.name, "noreply@picsello.com"})
    |> deliver_later()
  end

  def deliver_order_cancelation(
        %{
          delivery_info: %{email: email, name: client_name},
          gallery: %{job: %{client: %{organization: %{user: user} = organization}}} = gallery
        } = order,
        helpers
      ) do
    params = %{
      logo_url: Picsello.Profiles.logo_url(organization),
      headline: "Your order has been canceled",
      client_name: client_name,
      client_order_url: helpers.order_url(gallery, order),
      client_gallery_url: helpers.gallery_url(gallery),
      organization_name: organization.name,
      email_signature: email_signature(organization),
      order_number: Picsello.Cart.Order.number(order),
      order_date: helpers.strftime(user.time_zone, order.placed_at, "%-m/%-d/%y"),
      order_items:
        for product <- order.products do
          %{
            item_name: Picsello.Cart.product_name(product),
            item_quantity: Picsello.Cart.product_quantity(product)
          }
        end ++ List.duplicate(%{item_name: "Digital Download"}, length(order.digitals))
    }

    sendgrid_template(:client_order_canceled_template, params)
    |> to(email)
    |> from("noreply@picsello.com")
    |> subject("Order canceled")
    |> deliver_later()
  end

  def deliver_download_ready(%Gallery{} = gallery, download_link, helpers) do
    %{job: %{client: %{name: name, email: email, organization: organization}}} =
      Repo.preload(gallery, job: [client: :organization])

    deliver_download_ready(
      %{gallery: gallery, organization: organization, name: name, email: email},
      download_link,
      helpers
    )
  end

  def deliver_download_ready(
        %Order{delivery_info: %{email: email, name: name}} = order,
        download_link,
        helpers
      ) do
    %{gallery: %{organization: organization} = gallery} =
      Repo.preload(order, gallery: :organization)

    deliver_download_ready(
      %{gallery: gallery, organization: organization, name: name, email: email},
      download_link,
      helpers
    )
  end

  def deliver_download_ready(
        %{gallery: gallery, organization: organization, name: name, email: email},
        download_link,
        helpers
      ) do
    params = %{
      download_link: download_link,
      logo_url: Picsello.Profiles.logo_url(organization),
      name: name,
      gallery_url: helpers.gallery_url(gallery)
    }

    sendgrid_template(:client_download_ready_template, params)
    |> to(email)
    |> from("noreply@picsello.com")
    |> subject("Download Ready")
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

  defp deliver_transactional_email(params, recipients, %Job{} = job) do
    client = job |> Repo.preload(:client) |> Map.get(:client)
    reply_to = Messages.email_address(job)
    deliver_transactional_email(params, recipients, reply_to, client)
  end

  defp deliver_transactional_email(params, recipients, clients) do
    IO.inspect clients
    reply_to = Messages.email_address(hd(clients))
    deliver_transactional_email(params, recipients, reply_to, hd(clients))
  end

  defp deliver_transactional_email(params, recipients, reply_to, client) do
    client = client |> Repo.preload(organization: [:user])
    %{organization: organization} = client

    params =
      Map.merge(
        %{
          logo_url: if(organization.profile.logo, do: organization.profile.logo.url),
          organization_name: organization.name,
          email_signature: email_signature(organization)
        },
        params
      )

    from_display = organization.name

    :client_transactional_template
    |> sendgrid_template(params)
    |> put_header("reply-to", "#{from_display} <#{reply_to}>")
    |> from({from_display, "noreply@picsello.com"})
    |> to(get_emails(recipients, "to"))
    |> cc(get_emails(recipients, "cc"))
    |> bcc(get_emails(recipients, "bcc"))
    |> deliver_later()
  end

  defp deliver_transactional_email(params, recipients) do
    sendgrid_template(:generic_transactional_template, params)
    |> to(get_emails(recipients, "to"))
    |> cc(get_emails(recipients, "cc"))
    |> bcc(get_emails(recipients, "bcc"))
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  defp may_be_proofing_album_selection(nil), do: :order_confirmation_template
  defp may_be_proofing_album_selection(_), do: :proofing_selection_confirmation_template
end
