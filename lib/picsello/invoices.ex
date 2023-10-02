defmodule Picsello.Invoices do
  @moduledoc "context module for invoicing photographers for outstanding whcc costs"
  alias Picsello.{Cart.Order, Subscriptions, Payments}
  import Ecto.Query, only: [from: 2]
  import Picsello.Package, only: [validate_money: 2]

  defmodule Invoice do
    @moduledoc "represents a stripe invoice. one per order."
    use Ecto.Schema
    import Ecto.Changeset

    @statuses ~w[draft open paid void uncollectable]a

    schema "gallery_order_invoices" do
      field :amount_due, Money.Ecto.Map.Type
      field :amount_paid, Money.Ecto.Map.Type
      field :amount_remaining, Money.Ecto.Map.Type
      field :description, :string
      field :status, Ecto.Enum, values: @statuses
      field :stripe_id, :string

      belongs_to :order, Order

      timestamps(type: :utc_datetime)
    end

    def changeset(%Stripe.Invoice{id: stripe_id} = params, %Order{
          id: order_id,
          currency: currency
        }) do
      attrs = ~w[amount_due amount_paid amount_remaining description stripe_id status order_id]a

      cast(
        %__MODULE__{},
        params
        |> Map.from_struct()
        |> build_amounts(currency)
        |> Map.merge(%{stripe_id: stripe_id, order_id: order_id}),
        attrs
      )
      |> validate_required(attrs)
      |> foreign_key_constraint(:order_id)
      |> validate_money([:amount_due, :amount_paid, :amount_remaining])
      |> validate_inclusion(:status, @statuses)
    end

    def changeset(%__MODULE__{} = invoice, %Stripe.Invoice{} = params) do
      cast(
        invoice,
        Map.from_struct(params),
        ~w[amount_due amount_paid amount_remaining description status]a
      )
    end

    defp build_amounts(params, currency) do
      %{amount_due: amount_due, amount_paid: amount_paid, amount_remaining: amount_remaining} =
        params

      %{
        params
        | amount_due:
            if(is_map(amount_due), do: amount_due, else: Money.new(amount_due, currency)),
          amount_paid:
            if(is_map(amount_paid), do: amount_paid, else: Money.new(amount_paid, currency)),
          amount_remaining:
            if(is_map(amount_remaining),
              do: amount_remaining,
              else: Money.new(amount_remaining, currency)
            )
      }
    end
  end

  alias __MODULE__.Invoice

  defdelegate changeset(stripe_invoice, order), to: Invoice

  def pending_invoices?(organization_id) do
    from(
      invoice in Invoice,
      join: order in assoc(invoice, :order),
      join: gallery in assoc(order, :gallery),
      join: organization in assoc(gallery, :organization),
      where: organization.id == ^organization_id and invoice.status == :open
    )
    |> Picsello.Repo.exists?()
  end

  def invoice_user(user, %Money{amount: outstanding_cents, currency: :USD}, opts \\ []) do
    with "" <> customer <- Subscriptions.user_customer_id(user),
         {:ok, _invoice_item} <-
           Payments.create_invoice_item(%{
             customer: customer,
             amount: outstanding_cents,
             currency: Keyword.get(opts, :currency)
           }),
         {:ok, %{id: invoice_id}} <-
           Payments.create_invoice(%{
             customer: customer,
             description: Keyword.get(opts, :description, "Outstanding charges"),
             auto_advance: true
           }) do
      Payments.finalize_invoice(invoice_id, %{auto_advance: true})
    end
  end

  def open_invoice_for_order_query(%{id: order_id}),
    do: from(invoice in Invoice, where: invoice.order_id == ^order_id and invoice.status == :open)
end
