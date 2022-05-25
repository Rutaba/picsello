defmodule Picsello.Intents do
  @moduledoc "context module for tracking client payment intents."
  import Ecto.Query, only: [from: 2]
  alias Picsello.Repo

  defmodule Intent do
    @moduledoc "represents a stripe payment intent. one per order."
    use Ecto.Schema
    import Ecto.Changeset
    alias Picsello.Cart.Order

    schema "gallery_order_intents" do
      field :amount, Money.Ecto.Type
      field :amount_capturable, Money.Ecto.Type
      field :amount_received, Money.Ecto.Type
      field :application_fee_amount, Money.Ecto.Type
      field :description, :string

      field :status, Ecto.Enum,
        values:
          ~w[requires_payment_method requires_confirmation requires_capture requires_action processing succeeded canceled]a

      field :stripe_id, :string

      belongs_to :order, Order

      timestamps(type: :utc_datetime)
    end

    def changeset(%Stripe.PaymentIntent{id: stripe_id} = params, %Order{id: order_id}) do
      attrs =
        ~w[amount amount_received amount_capturable application_fee_amount description status stripe_id order_id]a

      cast(
        %__MODULE__{},
        params |> Map.from_struct() |> Map.merge(%{stripe_id: stripe_id, order_id: order_id}),
        attrs
      )
      |> validate_required(attrs)
    end

    def changeset(%__MODULE__{} = invoice, %Stripe.PaymentIntent{} = params) do
      attrs = ~w[amount amount_received amount_capturable status]a

      cast(invoice, Map.from_struct(params), attrs) |> validate_required(attrs)
    end
  end

  alias __MODULE__.Intent

  def create(payment_intent, order) do
    payment_intent |> Intent.changeset(order) |> Repo.insert()
  end

  def update(%Stripe.PaymentIntent{id: "" <> stripe_id} = intent) do
    Intent
    |> Repo.get_by(stripe_id: stripe_id)
    |> Intent.changeset(intent)
    |> Repo.update()
  end

  def capture(%Intent{stripe_id: stripe_id}, stripe_options) do
    case Picsello.Payments.capture_payment_intent(stripe_id, stripe_options) do
      {:ok, stripe_intent} -> update(stripe_intent)
      error -> error
    end
  end

  def unpaid_query(), do: from(intents in Intent, where: intents.status != :succeeded)
end
