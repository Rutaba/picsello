defmodule Picsello.PaymentSchedules do
  @moduledoc "context module for payment schedules"

  alias Picsello.{
    Repo,
    Job,
    Package,
    PaymentSchedule,
    Payments,
    Notifiers.UserNotifier,
    BookingProposal,
    Client
  }

  def build_payment_schedules_for_lead(%Job{} = job) do
    %{package: package, shoots: shoots} = job |> Repo.preload([:package, :shoots])

    price = package |> Package.price() |> Money.multiply(0.5)

    next_shoot_date =
      shoots
      |> Enum.sort_by(& &1.starts_at, DateTime)
      |> Enum.at(0)
      |> Map.get(:starts_at)
      |> DateTime.add(-1 * :timer.hours(24), :millisecond)
      |> DateTime.truncate(:second)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      %{
        price: price,
        job_id: job.id,
        due_at: now,
        inserted_at: now,
        updated_at: now,
        description: "50% retainer"
      },
      %{
        price: price,
        job_id: job.id,
        due_at: next_shoot_date,
        inserted_at: now,
        updated_at: now,
        description: "50% remainder"
      }
    ]
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
        UserNotifier.deliver_lead_converted_to_job(proposal, helpers.jobs_url())
      end

      update_result
    else
      {:error, _} = error -> error
      error -> {:error, error}
    end
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
