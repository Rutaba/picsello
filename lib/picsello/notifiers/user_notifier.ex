defmodule Picsello.Notifiers.UserNotifier do
  @moduledoc false
  alias Picsello.{Repo, Accounts.User, Job}
  alias Picsello.WHCC.Order.Created, as: WHCCOrder
  use Picsello.Notifiers
  import Money.Sigils
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
          :job_name => String.t(),
          :client_order_url => String.t(),
          :client_charge => Money.t(),
          optional(:print_credit_used) => Money.t(),
          optional(:print_credit_remaining) => Money.t(),
          optional(:print_cost) => Money.t(),
          optional(:photographer_charge) => Money.t(),
          optional(:photographer_payment) => Money.t()
        }
  def order_confirmation_params(
        %{
          gallery: %{job: job} = gallery,
          intent: intent,
          album_id: nil
        } = order,
        helpers
      ) do
    for(
      fun <- [
        &print_credit/1,
        &print_cost/1,
        &photographer_charge/1,
        &photographer_payment/1,
        &stripe_processing_fee/1
      ],
      reduce: %{
        gallery_name: gallery.name,
        job_name: Job.name(job),
        client_charge:
          case intent do
            %{amount: amount} -> amount
            nil -> ~M[0]USD
          end,
        client_order_url: helpers.order_url(gallery, order)
      }
    ) do
      params ->
        Map.merge(params, fun.(order))
    end
  end

  def order_confirmation_params(
        %{gallery: %{job: job} = gallery, album: album} = order,
        helpers
      ) do
    %{
      job_url: helpers.job_url(job.id),
      gallery_name: gallery.name,
      job_name: Job.name(job),
      order_url: helpers.proofing_album_selections_url(album, order)
    }
  end

  defp print_credit(%{products: products, gallery: gallery}) do
    products
    |> Enum.reduce(~M[0]USD, &Money.add(&2, &1.print_credit_discount))
    |> case do
      ~M[0]USD ->
        %{}

      credit ->
        %{
          print_credit_used: credit,
          print_credit_remaining: Picsello.Cart.credit_remaining(gallery).print
        }
    end
  end

  defp print_cost(%{whcc_order: nil}), do: %{}

  defp print_cost(%{whcc_order: whcc_order} = order) do
    shipping_price = Picsello.Cart.total_shipping(order)

    %{print_cost: whcc_order |> WHCCOrder.total() |> Money.add(shipping_price)}
  end

  defp photographer_payment(%{intent: nil}), do: %{}

  defp photographer_payment(%{
         intent: %{amount: amount, application_fee_amount: application_fee_amount}
       }),
       do: %{photographer_payment: Money.subtract(amount, application_fee_amount)}

  defp photographer_charge(%{invoice: nil}), do: %{}
  defp photographer_charge(%{invoice: %{amount_due: amount}}), do: %{photographer_charge: amount}

  defp stripe_processing_fee(%{intent: %{processing_fee: processing_fee}}),
    do: %{processing_fee: processing_fee}

  defp stripe_processing_fee(_), do: %{processing_fee: nil}

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
