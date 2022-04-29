defmodule Picsello.PaymentSchedules do
  @moduledoc "context module for payment schedules"
  import Money.Sigils

  alias Picsello.{
    Repo,
    Job,
    Package,
    PaymentSchedule,
    Payments,
    Notifiers.UserNotifier,
    BookingProposal,
    Client,
    Shoot
  }

  @zero_price ~M[0]USD

  def build_payment_schedules_for_lead(%Job{} = job) do
    %{package: package, shoots: shoots} = job |> Repo.preload([:package, :shoots])

    shoots = shoots |> Enum.sort_by(& &1.starts_at, DateTime)
    next_shoot = shoots |> Enum.at(0, %Shoot{}) |> Map.get(:starts_at)
    last_shoot = shoots |> Enum.at(-1, %Shoot{}) |> Map.get(:starts_at)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    price = if package, do: Package.price(package), else: @zero_price

    info =
      payment_schedules_info(%{
        type: job.type,
        price: price,
        next_shoot: next_shoot || now,
        last_shoot: last_shoot || now,
        now: now
      })

    info
    |> Map.put(
      :payments,
      for attributes <- info.payments do
        attributes
        |> Map.merge(%{
          job_id: job.id,
          inserted_at: now,
          updated_at: now
        })
      end
    )
  end

  def free?(%Job{} = job) do
    job
    |> payment_schedules()
    |> Enum.all?(&Money.zero?(&1.price))
  end

  defp payment_schedules_info(%{price: @zero_price, now: now}) do
    %{
      label: "Payment",
      details: "100% discount",
      payments: [%{description: "100% discount", due_at: now, price: @zero_price}]
    }
  end

  defp payment_schedules_info(%{type: type, price: price, now: now})
       when type in ~w[headshot  mini] do
    %{
      label: "Payment Due in Full",
      details: "100% retainer",
      payments: [%{description: "100% retainer", due_at: now, price: price}]
    }
  end

  defp payment_schedules_info(%{
         type: "wedding",
         price: price,
         now: now,
         last_shoot: wedding_date
       }) do
    seven_months_from_wedding = days_before(wedding_date, 30 * 7)
    one_month_from_wedding = days_before(wedding_date, 30)

    if :lt == DateTime.compare(seven_months_from_wedding, now) do
      %{
        label: "Advance Wedding Payment",
        details: "70% retainer and 30% one month before shoot",
        payments: [
          %{description: "70% retainer", due_at: now, price: Money.multiply(price, 0.7)},
          %{
            description: "30% remainder",
            due_at: one_month_from_wedding,
            price: Money.multiply(price, 0.3)
          }
        ]
      }
    else
      %{
        label: "Standard Wedding Payment",
        details: "35% retainer, 35% six months to the wedding, 30% one month before the wedding",
        payments: [
          %{description: "35% retainer", due_at: now, price: Money.multiply(price, 0.35)},
          %{
            description: "35% second payment",
            due_at: seven_months_from_wedding,
            price: Money.multiply(price, 0.35)
          },
          %{
            description: "30% remainder",
            due_at: one_month_from_wedding,
            price: Money.multiply(price, 0.30)
          }
        ]
      }
    end
  end

  defp payment_schedules_info(%{price: price, now: now, next_shoot: next_shoot}) do
    %{
      label: "Standard Payment",
      details: "50% retainer and 50% on day of shoot",
      payments: [
        %{description: "50% retainer", due_at: now, price: Money.multiply(price, 0.5)},
        %{
          description: "50% remainder",
          due_at: days_before(next_shoot, 1),
          price: Money.multiply(price, 0.5)
        }
      ]
    }
  end

  defp days_before(%DateTime{} = date, days) do
    date
    |> DateTime.add(-1 * days * :timer.hours(24), :millisecond)
    |> DateTime.truncate(:second)
  end

  def has_payments?(%Job{} = job) do
    job |> payment_schedules() |> Enum.any?()
  end

  def all_paid?(%Job{} = job) do
    job |> payment_schedules() |> Enum.all?(&PaymentSchedule.paid?/1)
  end

  def total_price(%Job{} = job) do
    job
    |> payment_schedules()
    |> Enum.reduce(Money.new(0), fn payment, acc -> Money.add(acc, payment.price) end)
  end

  def paid_price(%Job{} = job) do
    job
    |> payment_schedules()
    |> Enum.filter(&(&1.paid_at != nil))
    |> Enum.reduce(Money.new(0), fn payment, acc -> Money.add(acc, payment.price) end)
  end

  def owed_price(%Job{} = job) do
    job
    |> payment_schedules()
    |> Enum.filter(&(&1.paid_at == nil))
    |> Enum.reduce(Money.new(0), fn payment, acc -> Money.add(acc, payment.price) end)
  end

  def remainder_due_on(%Job{} = job) do
    job |> remainder_payment() |> Map.get(:due_at)
  end

  def remainder_paid_at(%Job{} = job) do
    job |> remainder_payment() |> Map.get(:paid_at)
  end

  def unpaid_payment(job) do
    job |> payment_schedules() |> Enum.find(&(!paid?(&1)))
  end

  def past_due?(%PaymentSchedule{due_at: due_at}) do
    :lt == DateTime.compare(due_at, DateTime.utc_now())
  end

  def payment_schedules(job) do
    Repo.preload(job, [:payment_schedules])
    |> Map.get(:payment_schedules)
  end

  def remainder_price(job) do
    remainder_payment(job).price
  end

  def handle_payment(
        %Stripe.Session{
          client_reference_id: "proposal_" <> proposal_id,
          metadata: %{"paying_for" => payment_schedule_id}
        },
        helpers
      ) do
    with %BookingProposal{} = proposal <-
           Repo.get(BookingProposal, proposal_id) |> Repo.preload(job: :job_status),
         %PaymentSchedule{} = payment_schedule <-
           Repo.get(PaymentSchedule, payment_schedule_id),
         {:ok, _} = update_result <-
           payment_schedule
           |> PaymentSchedule.paid_changeset()
           |> Repo.update() do
      if proposal.job.job_status.is_lead do
        UserNotifier.deliver_lead_converted_to_job(proposal, helpers)
      end

      update_result
    else
      {:error, _} = error -> error
      error -> {:error, error}
    end
  end

  def mark_as_paid(%BookingProposal{} = proposal, helpers) do
    Repo.transaction(fn ->
      proposal
      |> Repo.preload(:job)
      |> Map.get(:job)
      |> payment_schedules()
      |> Enum.each(&(&1 |> PaymentSchedule.paid_changeset() |> Repo.update!()))

      UserNotifier.deliver_lead_converted_to_job(proposal, helpers)
    end)
  end

  def checkout_link(%BookingProposal{} = proposal, line_items, opts) do
    cancel_url = opts |> Keyword.get(:cancel_url)
    success_url = opts |> Keyword.get(:success_url)

    %{job: %{client: %{organization: organization} = client}} =
      proposal |> Repo.preload(job: [client: :organization])

    customer_id = customer_id(client)

    stripe_params = %{
      client_reference_id: "proposal_#{proposal.id}",
      cancel_url: cancel_url,
      success_url: success_url,
      customer: customer_id,
      customer_update: %{
        address: "auto"
      },
      line_items: line_items,
      metadata: Keyword.get(opts, :metadata, %{})
    }

    Payments.checkout_link(stripe_params, connect_account: organization.stripe_account_id)
  end

  defp customer_id(%Client{stripe_customer_id: nil} = client) do
    params = %{name: client.name, email: client.email}
    %{organization: organization} = client |> Repo.preload(:organization)

    with {:ok, %{id: customer_id}} <-
           Payments.create_customer(params, connect_account: organization.stripe_account_id),
         {:ok, client} <-
           client
           |> Client.assign_stripe_customer_changeset(customer_id)
           |> Repo.update() do
      client.stripe_customer_id
    else
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  defp customer_id(%Client{stripe_customer_id: customer_id}), do: customer_id

  defp remainder_payment(job) do
    job |> payment_schedules() |> Enum.at(-1) || %PaymentSchedule{}
  end

  defdelegate paid?(payment_schedule), to: PaymentSchedule
end
