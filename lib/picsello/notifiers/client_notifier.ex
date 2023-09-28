defmodule Picsello.Notifiers.ClientNotifier do
  @moduledoc false
  use Picsello.Notifiers

  import Money.Sigils

  alias Picsello.{
    BookingProposal,
    Job,
    Repo,
    Cart,
    Messages,
    ClientMessage,
    Galleries.Gallery,
    Utils
  }

  alias Cart.Order
  require Logger

  @doc """
  Deliver booking proposal email.
  """
  def deliver_booking_proposal(message, recipients) do
    proposal = BookingProposal.last_for_job(message.job_id)

    deliver_email(message, recipients, %{
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
    message = message |> Repo.preload([:clients, job: :client], force: true)

    message
    |> message_params()
    |> Map.merge(params)
    |> deliver_transactional_email(recipients, message)
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

    booking_event = Map.get(job, :booking_event)
    name = if booking_event, do: booking_event.name, else: Picsello.Job.name(job)

    %{
      subject: "Cash or check payment",
      body: """
      <p>You said you will pay #{organization.name} for #{name} through a cash or check for the following #{Picsello.PaymentSchedules.owed_price(job) |> Money.to_string(fractional_unit: false)} it is due on #{Picsello.PaymentSchedules.remainder_due_on(job) |> Calendar.strftime("%B %d, %Y")}.</p>
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
      Logger.warning("job: #{inspect(job.id)}")
      Logger.warning("Proposal: #{inspect(proposal)}")

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
        Logger.warning("job: #{inspect(job.id)}")
        Logger.warning("something went wrong: #{inspect(error)}")
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
          album: album,
          bundle_price: nil
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
          is_credit: digital.is_credit,
          item_is_digital: true,
          item_price: if(digital.is_credit, do: "$0.00", else: digital.price)
        }
      end

    opts =
      %{
        client_name: client_name,
        order_first_name: String.split(client_name, " ") |> List.first(),
        photographer_organization_name: organization.name,
        contains_digital: digitals != [],
        contains_physical: products != [],
        gallery_url: helpers.gallery_url(gallery),
        gallery_name: gallery.name,
        order_address: products != [] && order_address(client_name, address),
        order_date: helpers.strftime(time_zone, order.placed_at, "%-m/%-d/%y"),
        order_items: products ++ digitals,
        order_number: Picsello.Cart.Order.number(order),
        order_shipping: order |> Cart.preload_products() |> Cart.total_shipping(),
        order_subtotal:
          Money.subtract(
            Order.total_cost(order),
            Cart.preload_products(order) |> Cart.total_shipping()
          ),
        order_total: Order.total_cost(order),
        order_url:
          if(order.album_id,
            do: helpers.proofing_album_selections_url(album, gallery, order),
            else: helpers.order_url(gallery, order)
          ),
        subject: "#{organization.name} - order ##{Picsello.Cart.Order.number(order)}",
        print_credits_remaining:
          Cart.print_credit_remaining(gallery.id) |> Map.get(:print, ~M[0]USD),
        print_credits_used:
          Cart.preload_products(order).products
          |> Enum.reduce(~M[0]USD, &Money.add(&2, &1.print_credit_discount)),
        digital_credits_remaining:
          Cart.digital_credit_remaining(gallery.id) |> Map.get(:digital, 0),
        digital_credits_used: digital_credits_used(order.digitals),
        email_signature: email_signature(organization)
      }
      |> Map.merge(logo_url(organization))

    order.album_id
    |> may_be_proofing_album_selection()
    |> sendgrid_template(opts)
    |> to({client_name, to_email})
    |> from({organization.name, "noreply@picsello.com"})
    |> deliver_later()
  end

  def deliver_order_confirmation(
        %{
          gallery:
            %{
              job: %{
                client: %{organization: %{user: %{time_zone: "" <> time_zone}} = organization}
              }
            } = gallery,
          delivery_info: %{name: client_name, email: to_email},
          bundle_price: bundle_price
        } = order,
        helpers
      ) do
    params =
      %{
        order_first_name: String.split(client_name, " ") |> List.first(),
        photographer_organization_name: organization.name,
        order_url: helpers.order_url(gallery, order),
        order_number: Picsello.Cart.Order.number(order),
        order_date: helpers.strftime(time_zone, order.placed_at, "%-m/%-d/%y"),
        order_subtotal:
          Money.subtract(
            Order.total_cost(order),
            Cart.preload_products(order) |> Cart.total_shipping()
          ),
        order_shipping: order |> Cart.preload_products() |> Cart.total_shipping(),
        order_total: Order.total_cost(order),
        contains_digital: true,
        order_items: [
          %{
            item_name: "Digital Downloads Bundle",
            item_quantity: "1",
            item_price: bundle_price,
            item_is_digital: true
          }
        ]
      }
      |> Map.merge(logo_url(organization))

    sendgrid_template(:download_being_prepared_client, params)
    |> to({client_name, to_email})
    |> from({organization.name, "noreply@picsello.com"})
    |> deliver_later()
  end

  defp digital_credits_used(digitals) do
    Enum.reduce(digitals, 0, fn digital, acc ->
      if digital.is_credit do
        acc + 1
      else
        acc
      end
    end)
  end

  def deliver_order_cancelation(
        %{
          delivery_info: %{email: email, name: client_name},
          gallery: %{job: %{client: %{organization: %{user: user} = organization}}} = gallery
        } = order,
        helpers
      ) do
    params =
      %{
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
      |> Map.merge(logo_url(organization))

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
    params =
      %{
        download_url: download_link,
        gallery_url: helpers.gallery_url(gallery),
        order_first_name: String.split(name, " ") |> List.first()
      }
      |> Map.merge(logo_url(organization))

    sendgrid_template(:client_download_ready_template, params)
    |> to(email)
    |> from("noreply@picsello.com")
    |> subject("Download Ready")
    |> deliver_later()
  end

  @doc """
    emails handle lead & job
  """
  def deliver_automation_email_job(email_preset, job, schema, _state, helpers) do
    with client <- job |> Repo.preload(:client) |> Map.get(:client),
         %{body_template: body, subject_template: subject} <-
           Picsello.EmailAutomations.resolve_variables(email_preset, schema, helpers) do
      body = Utils.normalize_body_template(body)

      deliver_transactional_email(
        %{subject: subject, headline: subject, body: body},
        %{"to" => client.email},
        job
      )
    end
  end

  def deliver_automation_email_gallery(email_preset, gallery, schema, _state, helpers) do
    %{body_template: body, subject_template: subject} =
      Picsello.EmailAutomations.resolve_variables(
        email_preset,
        schema,
        helpers
      )

    deliver_transactional_email(
      %{
        subject: subject,
        body: body
      },
      %{"to" => gallery.job.client.email}
    )
  end

  def deliver_automation_email_order(email_preset, order, _schema, _state, helpers) do
    with %{body_template: body, subject_template: subject} <-
           Picsello.EmailAutomations.resolve_variables(
             email_preset,
             {order.gallery, order},
             helpers
           ) do
      deliver_transactional_email(
        %{
          subject: subject,
          body: body
        },
        %{"to" => order.delivery_info.email},
        order.gallery.job
      )
    end
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

  defp deliver_transactional_email(params, recipients, %ClientMessage{} = message) do
    if message.job do
      reply_to = Messages.email_address(message.job)
      deliver_transactional_email(params, recipients, reply_to, message.job.client)
    else
      deliver_transactional_email(params, recipients)
    end
  end

  defp deliver_transactional_email(params, recipients, reply_to, client) do
    client = client |> Repo.preload(organization: [:user])
    %{organization: organization} = client

    params =
      Map.merge(
        %{
          organization_name: organization.name,
          email_signature: email_signature(organization)
        },
        params
      )
      |> Map.merge(logo_url(organization))

    from_display = organization.name

    :client_transactional_template
    |> sendgrid_template(params)
    |> put_header("reply-to", "#{from_display} <#{reply_to}>")
    |> from({from_display, "noreply@picsello.com"})
    |> to(map_recipients(Map.get(recipients, "to")))
    |> cc(map_recipients(Map.get(recipients, "cc")))
    |> bcc(map_recipients(Map.get(recipients, "bcc")))
    |> deliver_later()
  end

  defp deliver_transactional_email(params, recipients) do
    sendgrid_template(:generic_transactional_template, params)
    |> to(map_recipients(Map.get(recipients, "to")))
    |> cc(map_recipients(Map.get(recipients, "cc")))
    |> bcc(map_recipients(Map.get(recipients, "bcc")))
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  defp map_recipients(nil), do: nil

  defp map_recipients(recipients) do
    if is_list(recipients) do
      Enum.map(recipients, &{:email, String.trim(&1)})
    else
      String.split(recipients, ";")
      |> Enum.map(&{:email, String.trim(&1)})
    end
  end

  defp logo_url(organization) do
    case Picsello.Profiles.logo_url(organization) do
      nil -> %{organization_name: organization.name}
      url -> %{logo_url: url}
    end
  end

  defp may_be_proofing_album_selection(nil), do: :order_confirmation_template
  defp may_be_proofing_album_selection(_), do: :proofing_selection_confirmation_template
end
