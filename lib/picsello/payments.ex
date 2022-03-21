defmodule Picsello.Payments do
  alias Picsello.{
    Accounts.User,
    BookingProposal,
    Client,
    Notifiers.UserNotifier,
    Organization,
    PaymentSchedule,
    Cart.Order,
    Repo
  }

  alias PicselloWeb.Router.Helpers, as: Routes

  require Logger

  @moduledoc "behavior of (stripe) payout processor"

  @type product_data() :: %{
          :name => String.t(),
          optional(:description) => String.t(),
          optional(:images) => [String.t()],
          optional(:metadata) => Stripe.Types.metadata()
        }

  @type price_data() :: %{
          :currency => String.t(),
          optional(:product_data) => product_data(),
          optional(:unit_amount) => integer()
        }

  @type line_item() :: %{
          optional(:name) => String.t(),
          optional(:quantity) => integer(),
          optional(:amount) => integer(),
          optional(:currency) => String.t(),
          optional(:description) => String.t(),
          optional(:dynamic_tax_rates) => [String.t()],
          optional(:images) => [String.t()],
          optional(:price) => String.t(),
          optional(:price_data) => price_data(),
          optional(:tax_rates) => [String.t()]
        }

  #  https://hexdocs.pm/stripity_stripe/Stripe.Session.html#t:create_params/0
  @type create_session() :: %{
          :cancel_url => String.t(),
          :line_items => [line_item()],
          :success_url => String.t(),
          optional(:client_reference_id) => String.t(),
          optional(:customer) => String.t(),
          optional(:customer_email) => String.t(),
          optional(:metadata) => Stripe.Types.metadata()
        }

  @type create_customer() :: %{
          optional(:email) => String.t(),
          optional(:name) => String.t()
        }

  @type create_account_link() :: %{
          :account => Stripe.Account.t() | Stripe.id(),
          :refresh_url => String.t(),
          :return_url => String.t(),
          :type => String.t(),
          optional(:collect) => String.t()
        }

  @callback create_customer(create_customer(), Stripe.options()) ::
              {:ok, Stripe.Customer.t()} | {:error, Stripe.Error.t()}

  @callback checkout_link(create_session(), Stripe.options()) ::
              {:ok, String.t()}

  @callback construct_event(String.t(), String.t(), String.t()) ::
              {:ok, Stripe.Event.t()} | {:error, any}

  @callback retrieve_session(String.t(), keyword(binary())) ::
              {:ok, Stripe.Session.t()} | {:error, Stripe.Error.t()}

  @callback retrieve_account(binary()) ::
              {:ok, Stripe.Account.t()} | {:error, Stripe.Error.t()}

  @callback create_account_link(create_account_link(), Stripe.options()) ::
              {:ok, Stripe.AccountLink.t()} | {:error, Stripe.Error.t()}

  @callback login_link(%User{}, keyword(binary())) :: {:ok, binary()}
  @callback login_link(%Organization{}, keyword(binary())) :: {:ok, binary()}

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

    checkout_link(stripe_params, connect_account: organization.stripe_account_id)
  end

  def checkout_link(%Order{products: products, shipping_cost: shipping_cost}, opts) do
    params = cart_checkout_params(products, shipping_cost, opts)

    case checkout_link(params, []) do
      {:ok, url} -> {:ok, %{link: url, line_items: params.line_items}}
      error -> error
    end
  end

  def checkout_link(params, opts), do: impl().checkout_link(params, opts)
  def create_customer(params, opts), do: impl().create_customer(params, opts)
  def retrieve_session(id, opts), do: impl().retrieve_session(id, opts)
  def retrieve_account(id), do: impl().retrieve_account(id)
  def create_account_link(params), do: impl().create_account_link(params, [])

  def construct_event(body, signature, secret),
    do: impl().construct_event(body, signature, secret)

  def cart_checkout_params(products, shipping_cost, opts) do
    cancel_url = opts |> Keyword.get(:cancel_url)
    success_url = opts |> Keyword.get(:success_url)

    %{
      cancel_url: cancel_url,
      success_url: success_url,
      line_items: form_order_line_items(products),
      shipping_options: [
        %{
          shipping_rate_data: %{
            type: "fixed_amount",
            display_name: "Shipping",
            fixed_amount: %{
              amount: shipping_cost.amount,
              currency: shipping_cost.currency
            }
          }
        }
      ]
    }
  end

  @spec status(%Organization{} | %User{}) ::
          {:ok, :none | :processing | :charges_enabled | :details_submitted}
  def status(%User{} = user) do
    %{organization: organization} = user |> Repo.preload(:organization)
    status(organization)
  end

  def status(%Organization{stripe_account_id: nil}), do: :no_account

  def status(%Organization{stripe_account_id: account_id}) do
    Picsello.StripeStatusCache.current_for(account_id, fn ->
      case retrieve_account(account_id) do
        {:ok, account} ->
          account_status(account)

        {:error, error} ->
          Logger.error(error)
          :error
      end
    end)
  end

  def account_status(%Stripe.Account{charges_enabled: true}), do: :charges_enabled

  def account_status(%Stripe.Account{
        requirements: %{disabled_reason: "requirements.pending_verification"}
      }),
      do: :pending_verification

  def account_status(%Stripe.Account{}), do: :missing_information

  def handle_payment(%Stripe.Session{
        client_reference_id: "proposal_" <> proposal_id,
        metadata: %{"paying_for" => payment_schedule_id}
      }) do
    with %BookingProposal{} = proposal <-
           Repo.get(BookingProposal, proposal_id) |> Repo.preload(job: :job_status),
         %PaymentSchedule{} = payment_schedule <- Repo.get(PaymentSchedule, payment_schedule_id),
         {:ok, _} = update_result <-
           payment_schedule
           |> PaymentSchedule.paid_changeset()
           |> Repo.update() do
      if proposal.job.job_status.is_lead do
        url = Routes.job_url(PicselloWeb.Endpoint, :jobs)
        UserNotifier.deliver_lead_converted_to_job(proposal, url)
      end

      update_result
    else
      {:error, _} = error -> error
      error -> {:error, error}
    end
  end

  def link(%User{} = user, opts) do
    %{organization: organization} = user |> Repo.preload(:organization)
    link(organization, opts)
  end

  def link(%Organization{stripe_account_id: nil} = organization, opts) do
    with {:ok, %{id: account_id}} <-
           create_account_link(%{type: "standard"}),
         {:ok, organization} <-
           organization
           |> Organization.assign_stripe_account_changeset(account_id)
           |> Repo.update() do
      link(organization, opts)
    else
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  def link(%Organization{stripe_account_id: account_id}, opts) do
    refresh_url = opts |> Keyword.get(:refresh_url)
    return_url = opts |> Keyword.get(:return_url)

    case create_account_link(%{
           account: account_id,
           refresh_url: refresh_url,
           return_url: return_url,
           type: "account_onboarding"
         }) do
      {:ok, %{url: url}} -> {:ok, url}
      error -> error
    end
  end

  defp form_order_line_items(products) do
    Enum.map(products, fn %{
                            price: price,
                            editor_details: %{
                              selections: %{"quantity" => quantity},
                              preview_url: preview_url
                            }
                          } = product ->
      unit_amount = price |> Money.divide(quantity) |> List.first() |> then(& &1.amount)

      %{
        price_data: %{
          currency: price.currency,
          unit_amount: unit_amount,
          product_data: %{
            name: Picsello.Cart.product_name(product),
            images: [preview_url]
          }
        },
        quantity: quantity
      }
    end)
  end

  defp customer_id(%Client{stripe_customer_id: nil} = client) do
    params = %{name: client.name, email: client.email}
    %{organization: organization} = client |> Repo.preload(:organization)

    with {:ok, %{id: customer_id}} <-
           create_customer(params, connect_account: organization.stripe_account_id),
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

  defp impl, do: Application.get_env(:picsello, :payments)
end
