defmodule Picsello.Invoices do
  @moduledoc "context module for invoicing photographers for outstanding whcc costs"
  alias Picsello.Cart.Order
  import Ecto.Query, only: [from: 2]
  import Picsello.Package, only: [validate_money: 2]

  defmodule Invoice do
    @moduledoc "represents a stripe invoice. one per order."
    use Ecto.Schema
    import Ecto.Changeset

    @statuses ~w[draft open paid void uncollectable]a

    schema "gallery_order_invoices" do
      field :amount_due, Money.Ecto.Type
      field :amount_paid, Money.Ecto.Type
      field :amount_remaining, Money.Ecto.Type
      field :description, :string
      field :status, Ecto.Enum, values: @statuses
      field :stripe_id, :string

      belongs_to :order, Order

      timestamps(type: :utc_datetime)
    end

    def changeset(%Stripe.Invoice{id: stripe_id} = params, %Order{id: order_id}) do
      attrs = ~w[amount_due amount_paid amount_remaining description stripe_id status order_id]a

      cast(
        %__MODULE__{},
        params |> Map.from_struct() |> Map.merge(%{stripe_id: stripe_id, order_id: order_id}),
        attrs
      )
      |> validate_required(attrs)
      |> foreign_key_constraint(:order_id)
      |> unique_constraint(:order_id)
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
  end

  alias __MODULE__.Invoice

  defdelegate changeset(stripe_invoice, order), to: __MODULE__.Invoice

  def unpaid_query() do
    from(invoices in Invoice,
      where: invoices.status != :paid
    )
  end

  def pending_invoices?(organization_id) do
    from(
      invoice in unpaid_query(),
      join: order in assoc(invoice, :order),
      join: gallery in assoc(order, :gallery),
      join: organization in assoc(gallery, :organization),
      where: organization.id == ^organization_id
    )
    |> Picsello.Repo.exists?()
  end
end
