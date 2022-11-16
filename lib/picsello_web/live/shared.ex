defmodule PicselloWeb.Live.Shared do
  alias Ecto.Changeset
  alias Picsello.Package

  import PicselloWeb.PackageLive.Shared,
    only: [current: 1]

  defmodule CustomPaymentSchedule do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :price, Money.Ecto.Amount.Type
      field :due_date, :date
    end

    def changeset(payment_schedule, attrs \\ %{}) do
      payment_schedule
      |> cast(attrs, [:price, :due_date])
      |> validate_required([:price, :due_date])
      |> Package.validate_money(:price, greater_than: 0)
    end
  end

  defmodule CustomPayments do
    @moduledoc "For setting payments on last step"
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:remaining_price, Money.Ecto.Amount.Type)
      embeds_many(:payment_schedules, CustomPaymentSchedule)
    end

    def changeset(attrs) do
      %__MODULE__{}
      |> cast(attrs, [:remaining_price])
      |> cast_embed(:payment_schedules)
      |> validate_total_amount()
    end

    defp validate_total_amount(changeset) do
      remaining = PicselloWeb.Live.Shared.remaining_to_collect(changeset)

      if Money.zero?(remaining) do
        changeset
      else
        add_error(changeset, :remaining_price, "is not valid")
      end
    end
  end

  def step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1

  def total_remaining_amount(package_changeset) do
    base_price = Changeset.get_field(package_changeset, :base_price) || Money.new(0)

    collected_price = Changeset.get_field(package_changeset, :collected_price) || Money.new(0)

    base_price |> Money.subtract(collected_price)
  end

  def remaining_to_collect(payments_changeset) do
    %{
      remaining_price: remaining_price,
      payment_schedules: payments
    } = payments_changeset |> current()

    total_collected =
      payments
      |> Enum.reduce(Money.new(0), fn payment, acc ->
        Money.add(acc, payment.price || Money.new(0))
      end)

    Money.subtract(remaining_price, total_collected)
  end

  def remaining_amount_zero?(package_changeset),
    do: package_changeset |> total_remaining_amount() |> Money.zero?()

  def base_price_zero?(package_changeset),
    do: (Changeset.get_field(package_changeset, :base_price) || Money.new(0)) |> Money.zero?()

  def maybe_insert_payment_schedules(multi_changes, %{assigns: assigns}) do
    if remaining_amount_zero?(assigns.package_changeset) do
      multi_changes
    else
      multi_changes
      |> Ecto.Multi.insert_all(:payment_schedules, Picsello.PaymentSchedule, fn changes ->
        assigns.payments_changeset
        |> current()
        |> Map.get(:payment_schedules)
        |> Enum.with_index()
        |> make_payment_schedule(changes)
      end)
    end
  end

  defp make_payment_schedule(multi_changes, changes) do
    multi_changes
    |> Enum.map(fn {payment_schedule, i} ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, due_at} =
        payment_schedule.due_date
        |> DateTime.new(~T[00:00:00])

      %{
        price: payment_schedule.price,
        due_at: due_at,
        job_id: changes.job.id,
        inserted_at: now,
        updated_at: now,
        description: "Payment #{i + 1}"
      }
    end)
  end

  def heading_subtitle(step) do
    Map.get(
      %{
        get_started: "Get Started",
        add_client: "General Details",
        job_details: "General Details",
        package_payment: "Package & Payment",
        invoice: "Custom Invoice",
        documents: "Documents (optional)"
      },
      step
    )
  end
end
