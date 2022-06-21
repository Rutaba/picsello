defmodule Picsello.PaymentSchedule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "payment_schedules" do
    field :price, Money.Ecto.Amount.Type
    field :due_at, :utc_datetime
    field :reminded_at, :utc_datetime
    field :paid_at, :utc_datetime
    field :description, :string
    belongs_to :job, Picsello.Job

    timestamps(type: :utc_datetime)
  end

  def paid_changeset(payment_schedule) do
    change(payment_schedule, %{paid_at: DateTime.truncate(DateTime.utc_now(), :second)})
  end

  def reminded_at_changeset(payment_schedule) do
    change(payment_schedule, %{reminded_at: DateTime.truncate(DateTime.utc_now(), :second)})
  end

  def paid?(%__MODULE__{paid_at: paid_at}), do: paid_at != nil
end
