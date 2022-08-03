defmodule Picsello.Intents do
  @moduledoc "context module for tracking client payment intents."
  import Ecto.Query, only: [from: 2]
  alias Picsello.Repo

  defmodule Intent do
    @moduledoc "represents a stripe payment intent. one per order."
    use Ecto.Schema
    import Ecto.Changeset
    alias Picsello.Cart.Order

    @statuses ~w[requires_payment_method requires_confirmation requires_capture requires_action processing succeeded canceled]a

    schema "gallery_order_intents" do
      field :amount, Money.Ecto.Type
      field :amount_capturable, Money.Ecto.Type
      field :amount_received, Money.Ecto.Type
      field :application_fee_amount, Money.Ecto.Type

      field :status, Ecto.Enum, values: @statuses

      field :stripe_payment_intent_id, :string
      field :stripe_session_id, :string

      belongs_to :order, Order

      timestamps(type: :utc_datetime)
    end

    def changeset(%Stripe.PaymentIntent{id: stripe_id} = params, opts) do
      required_attrs =
        ~w[amount amount_received amount_capturable status stripe_payment_intent_id stripe_session_id order_id]a

      cast(
        %__MODULE__{},
        params
        |> Map.from_struct()
        |> Map.merge(%{
          stripe_payment_intent_id: stripe_id,
          order_id: Keyword.get(opts, :order_id),
          stripe_session_id: Keyword.get(opts, :session_id)
        }),
        [:application_fee_amount | required_attrs]
      )
      |> validate_required(required_attrs)
      |> validate_one_uncancelled()
    end

    def changeset(%__MODULE__{} = intent, %Stripe.PaymentIntent{} = params) do
      attrs = ~w[amount amount_received amount_capturable status]a

      cast(intent, Map.from_struct(params), attrs)
      |> validate_required(attrs)
      |> validate_one_uncancelled()
    end

    defp validate_one_uncancelled(changeset) do
      unique_constraint(changeset, [:order_id, :status],
        name: "gallery_order_intents_uncanceled_order_id",
        message: "only one uncancelled intent per order"
      )
    end

    def statuses, do: @statuses
  end

  alias __MODULE__.Intent

  defdelegate changeset(stripe_intent, order), to: Intent

  def update_changeset(%Stripe.PaymentIntent{id: "" <> stripe_id} = intent) do
    Intent
    |> Repo.get_by(stripe_payment_intent_id: stripe_id)
    |> Intent.changeset(intent)
  end

  def update(intent) do
    intent |> update_changeset() |> Repo.update()
  end

  def capture(%Intent{stripe_payment_intent_id: stripe_id}, stripe_options) do
    case Picsello.Payments.capture_payment_intent(stripe_id, stripe_options) do
      {:ok, stripe_intent} -> update(stripe_intent)
      error -> error
    end
  end

  def unpaid_query(),
    do:
      from(intents in Intent,
        where: intents.status not in [:succeeded, :requires_capture, :canceled]
      )

  def unresolved_for_order(order_id) do
    resolved_statuses = [:succeeded, :canceled]

    from(intent in Intent,
      where: intent.order_id == ^order_id and intent.status not in ^resolved_statuses
    )
  end
end
