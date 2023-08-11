defmodule Picsello.Notifiers.UserNotifier do
  @moduledoc false
  alias Picsello.{Repo, Cart, Accounts.User, Job}
  alias Picsello.WHCC.Order.Created, as: WHCCOrder
  use Picsello.Notifiers
  require Logger

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    sendgrid_template(:confirmation_instructions_template, name: user.name, url: url)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver notification for download start.
  """
  def deliver_download_start_notification(user, gallery) do
    sendgrid_template(:download_being_prepared_photog,
      gallery_name: gallery.name,
      gallery_url: PicselloWeb.Helpers.gallery_url(gallery)
    )
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver notification for download start.
  """
  def deliver_download_ready_notification(user, gallery_name, gallery_url, download_url) do
    Logger.info("[Download_url] #{download_url}")

    sendgrid_template(:download_ready_photog,
      gallery_name: gallery_name,
      gallery_url: gallery_url,
      download_url: download_url
    )
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    sendgrid_template(:password_reset_template, name: user.name, url: url)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  def deliver_provider_auth_instructions(%{sign_up_auth_provider: provider} = user, url) do
    %{
      subject: "Sign into your Picsello account",
      body: """
      <p>Hello #{User.first_name(user)},</p>
      <p>You signed up for picsello using #{provider}.</p>
      <p><a href="#{url}">Click here</a> to sign into Picsello via #{provider}.</p>
      <p>Cheers!</p>
      """
    }
    |> deliver_transactional_email(user)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    sendgrid_template(:update_email_template, name: user.name, url: url)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  @doc """
  Deliver lead converted to job email.
  """
  def deliver_lead_converted_to_job(proposal, helpers) do
    %{
      job:
        %{
          client: %{organization: %{user: user}} = client,
          booking_event: booking_event
        } = job
    } = proposal |> Repo.preload(job: [:booking_event, client: [organization: :user]])

    case booking_event do
      nil ->
        %{
          subject: "#{client.name} just completed their booking proposal!",
          body: """
          <p>Hello #{User.first_name(user)},</p>
          <p>Yay! You have a new job!</p>
          <p>#{client.name} completed their proposal. We have moved them from a lead to a job. Congratulations!</p>
          <p>Click <a href="#{helpers.job_url(job.id)}">here</a> to view and access your job on Picsello.</p>
          <p>Cheers!</p>
          """
        }

      _ ->
        %{
          subject: "#{client.name} just booked your event: #{booking_event.name}!",
          body: """
          <p>Hello #{User.first_name(user)},</p>
          <p>Yay! You have a new booking from: #{booking_event.name}</p>
          <p>#{client.name} completed their proposal. We have added it to your jobs at the specified time. Congratulations!</p>
          <p>Click <a href="#{helpers.job_url(job.id)}">here</a> to view and access your job on Picsello.</p>
          <p>Cheers!</p>
          """
        }
    end
    |> deliver_transactional_email(user)
  end

  def deliver_paying_by_invoice(proposal) do
    %{job: %{client: %{organization: %{user: user}}} = job} =
      proposal |> Repo.preload(job: [client: [organization: :user]])

    %{
      subject: "Cash or check payment",
      body: """
      <p>Your client said they will pay #{Picsello.Job.name(job)} offline for the following #{Picsello.PaymentSchedules.owed_price(job) |> Money.to_string(fractional_unit: false)} it is due on #{Picsello.PaymentSchedules.remainder_due_on(job) |> Calendar.strftime("%B %d, %Y")}.</p>
      <p>Please arrange payment with them.</p>
      """
    }
    |> deliver_transactional_email(user)
  end

  @doc """
  Deliver new lead email.
  """
  def deliver_new_lead_email(job, message, helpers) do
    %{client: %{organization: %{user: user}} = client} =
      job |> Repo.preload(client: [organization: [:user]])

    %{
      subject: "You have a new lead from #{client.name}",
      body: """
      <p>Hello #{User.first_name(user)},</p>
      <p>Yay! You have a new lead!</p>
      <p>#{client.name} just submitted a contact form with the following information:</p>
      <p>Email: #{client.email}</p>
      <p>Phone: #{client.phone}</p>
      <p>Job Type: #{helpers.dyn_gettext(job.type)}</p>
      <p>Notes: #{message}</p>
      <p>Click <a href="#{helpers.lead_url(job.id)}">here</a> to view and access your lead on Picsello.</p>
      <p>Cheers!</p>
      """
    }
    |> deliver_transactional_email(user)
  end

  @doc """
  Deliver new inbound message email.
  """
  def deliver_new_inbound_message_email(client_message, helpers) do
    %{job: %{client: %{organization: %{user: user}} = client} = job} =
      client_message |> Repo.preload(job: [client: [organization: :user]])

    %{
      subject: "You’ve got mail!",
      body: """
      <p>Hello #{User.first_name(user)},</p>
      <p>You have received a reply from #{client.name}!</p>
      <p>Click <a href="#{helpers.inbox_thread_url(job.id)}">here</a> to view and access your emails on Picsello.</p>
      <p>Cheers!</p>
      """
    }
    |> deliver_transactional_email(user)
  end

  def deliver_shipping_notification(event, order, helpers) do
    with %{gallery: gallery} <- order |> Repo.preload(:gallery),
         [preset | _] <- Picsello.EmailPresets.for(gallery, :gallery_shipping_to_photographer),
         %{shipping_info: [%{tracking_url: tracking_url} | _]} <- event,
         %{body_template: body, subject_template: subject} <-
           Picsello.EmailPresets.resolve_variables(preset, {gallery, order}, helpers) do
      deliver_transactional_email(
        %{
          subject: subject,
          body: body,
          button: %{
            text: "Track shipping",
            url: tracking_url
          }
        },
        Picsello.Galleries.gallery_photographer(gallery)
      )
    end
  end

  @spec deliver_order_confirmation(Picsello.Cart.Order.t(), module()) ::
          {:ok, Bamboo.Email.t()} | {:error, any()}
  def deliver_order_confirmation(
        %{gallery: %{job: %{client: %{organization: %{user: user}}}}} = order,
        helpers
      ) do
    order.album_id
    |> maybe_proofing_album_selection()
    |> sendgrid_template(order_confirmation_params(order, helpers))
    |> to({User.first_name(user), user.email})
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  def deliver_order_cancelation(
        %{gallery: %{job: %{client: %{organization: %{user: user}}} = job} = gallery} = order,
        helpers
      ) do
    params = %{
      client_charge: Picsello.Cart.Order.total_cost(order),
      client_order_url: helpers.order_url(gallery, order),
      gallery_name: gallery.name,
      job_name: Picsello.Job.name(job),
      order_date: helpers.strftime(user.time_zone, order.placed_at, "%-m/%-d/%y"),
      order_number: Picsello.Cart.Order.number(order)
    }

    sendgrid_template(:photographer_order_canceled_template, params)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> subject("Order canceled")
    |> deliver_later()
  end

  @spec order_confirmation_params(Picsello.Cart.Order.t(), module()) :: %{
          :gallery_name => String.t(),
          :client_name => String.t(),
          :job_name => String.t(),
          :client_order_url => String.t(),
          :products_quantity => String.t(),
          :total_products_price => Money.t(),
          :client_charge => Money.t(),
          :total_costs => Money.t(),
          optional(:digital_credit_used) => Money.t(),
          optional(:digital_credit_remaining) => integer(),
          optional(:contains_digital) => boolean(),
          optional(:contains_product) => boolean(),
          optional(:digital_quantity) => String.t(),
          optional(:total_digitals_price) => Money.t(),
          optional(:print_credits_available) => boolean(),
          optional(:print_credit_used) => Money.t(),
          optional(:print_credit_remaining) => Money.t(),
          optional(:print_cost) => Money.t(),
          optional(:photographer_charge) => Money.t(),
          optional(:photographer_payment) => Money.t(),
          optional(:stripe_fee) => Money.t(),
          optional(:shipping) => Money.t(),
          optional(:positive_shipping) => Money.t()
        }
  def order_confirmation_params(
        %{
          gallery: %{job: %{client: client} = job} = gallery,
          intent: intent,
          album_id: nil,
          currency: currency
        } = order,
        helpers
      ) do
    zero_price = Money.new(0, currency)

    temp_params =
      for(
        fun <- [
          &print_credit/1,
          &print_cost/1,
          &photographer_payment/1,
          &digital_params/1,
          &products_params/1
        ],
        reduce: %{
          gallery_name: gallery.name,
          job_name: Job.name(job),
          client_name: client.name,
          client_charge:
            case intent do
              %{amount: amount} -> amount
              nil -> zero_price
            end,
          client_order_url: helpers.order_url(gallery, order)
        }
      ) do
        params ->
          Map.merge(params, fun.(order))
      end

    stripe_fee = Map.get(temp_params, :stripe_fee, zero_price)
    shipping = Map.get(temp_params, :shipping, zero_price)

    total_costs =
      stripe_fee
      |> Money.add(Map.get(temp_params, :print_cost, zero_price))
      |> Money.add(shipping)

    Map.merge(temp_params, %{total_costs: total_costs, positive_shipping: Money.neg(shipping)})
  end

  def order_confirmation_params(
        %{gallery: %{job: job} = gallery, album: album} = order,
        helpers
      ) do
    %{
      job_url: helpers.job_url(job.id),
      gallery_name: gallery.name,
      job_name: Job.name(job),
      order_url: helpers.proofing_album_selections_url(album, gallery, order)
    }
  end

  defp digital_params(%{gallery: gallery, currency: currency} = order) do
    case Map.get(order, :digitals) do
      [] ->
        %{}

      [_ | _] ->
        %{
          contains_digital: true,
          digital_quantity: "#{Enum.count(order.digitals)}",
          total_digitals_price:
            Enum.reduce(order.digitals, Money.new(0, currency), fn digital, acc ->
              Money.add(digital.price, acc)
            end),
          digital_credit_remaining: Map.get(Cart.credit_remaining(gallery), :digital, 0),
          digital_credit_used:
            Enum.reduce(order.digitals, Money.new(0, currency), fn digital, acc ->
              if digital.is_credit do
                Money.add(digital.price, acc)
              else
                acc
              end
            end)
            |> case do
              %{amount: 0} -> %{}
              credit -> credit |> Money.neg()
            end
        }

      _ ->
        %{}
    end
  end

  defp products_params(order) do
    products = Cart.preload_products(order).products

    total_products_price =
      products
      |> Enum.reduce(Money.new(0, order.currency), fn product, acc ->
        Money.add(product.price, acc)
      end)

    products_quantity =
      products
      |> Enum.reduce(0, fn product, acc ->
        Cart.product_quantity(product) + acc
      end)

    %{
      shipping: Picsello.Cart.total_shipping(order) |> Money.neg(),
      total_products_price: total_products_price,
      products_quantity: products_quantity,
      contains_product: Enum.any?(products)
    }
  end

  defp print_credit(%{products: products, gallery: gallery} = order) do
    products
    |> Enum.reduce(Money.new(0, order.currency), &Money.add(&2, &1.print_credit_discount))
    |> case do
      %{amount: _amount, currency: :USD} = credit ->
        %{
          print_credits_available: true,
          print_credit_used: credit |> Money.neg(),
          print_credit_remaining: Picsello.Cart.credit_remaining(gallery).print
        }

      _ ->
        %{}
    end
  end

  defp print_cost(%{whcc_order: nil}), do: %{}

  defp print_cost(%{whcc_order: whcc_order}) do
    %{
      print_cost:
        whcc_order
        |> WHCCOrder.total()
        |> Money.neg()
    }
  end

  defp photographer_payment(%{intent: nil}), do: %{}

  defp photographer_payment(
         %{
           currency: currency,
           whcc_order: whcc_order,
           intent: %{
             amount: amount,
             application_fee_amount: _application_fee_amount
           }
         } = order
       ) do
    zero_price = Money.new(0, currency)

    cost =
      if is_nil(whcc_order) do
        zero_price
      else
        WHCCOrder.total(whcc_order)
      end
      |> Money.add(Picsello.Cart.total_shipping(order))

    actual_costs_and_fees = actual_stripe_fee(amount, currency) |> Money.add(cost)
    costs_and_fees = cost |> stripe_fee(currency) |> Money.add(cost)

    case Money.cmp(amount, actual_costs_and_fees) do
      :gt ->
        %{
          photographer_payment: Money.subtract(amount, actual_costs_and_fees),
          photographer_charge: zero_price,
          stripe_fee: actual_stripe_fee(amount, currency) |> Money.neg()
        }

      :lt ->
        %{
          photographer_payment: zero_price,
          photographer_charge: Money.subtract(costs_and_fees, amount) |> Money.neg(),
          stripe_fee: stripe_fee(cost, currency) |> Money.neg()
        }

      _ ->
        %{
          photographer_payment: zero_price,
          photographer_charge: zero_price,
          stripe_fee: actual_stripe_fee(amount, currency) |> Money.neg()
        }
    end
  end

  # stripe's actual formula to calculate fee
  defp actual_stripe_fee(amount, currency) do
    amount
    |> Money.multiply(2.9 / 100)
    |> Money.add(Money.new(30, currency))
  end

  # our formula to calculate fee to be on safe side
  defp stripe_fee(amount, currency) do
    amount
    |> Money.multiply(2.9 / 100)
    |> Money.add(Money.new(70, currency))
  end

  defp deliver_transactional_email(params, user) do
    sendgrid_template(:generic_transactional_template, params)
    |> to(user.email)
    |> from("noreply@picsello.com")
    |> deliver_later()
  end

  defp maybe_proofing_album_selection(nil), do: :photographer_order_confirmation_template

  defp maybe_proofing_album_selection(_),
    do: :photographer_proofing_selection_confirmation_template
end
