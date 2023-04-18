defmodule Picsello.Notifiers.UserNotifierTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Cart, Cart.Order, Notifiers.UserNotifier}
  import Money.Sigils

  setup do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok
  end

  def deliver_order_confirmation(order) do
    UserNotifier.deliver_order_confirmation(order, PicselloWeb.Helpers)
  end

  def template_variables(%{
        private: %{send_grid_template: %{dynamic_template_data: template_variables}}
      }),
      do: for({k, v} <- template_variables, into: %{}, do: {String.to_existing_atom(k), v})

  def insert_gallery(%{package: package}) do
    [gallery: insert(:gallery, job: insert(:lead, package: package))]
  end

  def insert_gallery(_) do
    insert_gallery(%{package: insert(:package)})
  end

  def insert_order(%{gallery: gallery, products: products}) do
    order =
      for product <- products, reduce: nil do
        _ ->
          Cart.place_product(product, gallery)
      end
      |> Repo.preload(
        [
          :products,
          :digitals,
          :invoice,
          :intent,
          gallery: [job: [:package, client: [organization: :user]]]
        ],
        force: true
      )

    [
      order:
        order
        |> Cart.add_default_shipping_to_products()
        |> then(&Map.put(order, :products, &1))
    ]
  end

  def add_whcc_order(%{order: order}) do
    [
      order:
        order
        |> Order.whcc_order_changeset(build(:whcc_order_created, total: ~M[500]USD))
        |> Repo.update!()
    ]
  end

  def shared_fields(order) do
    %{
      client_order_url:
        PicselloWeb.Router.Helpers.gallery_client_order_url(
          PicselloWeb.Endpoint,
          :show,
          order.gallery.client_link_hash,
          Order.number(order),
          pw: order.gallery.password
        ),
      gallery_name: "Test Client Wedding",
      job_name: "Mary Jane Wedding"
    }
  end

  describe "deliver_order_confirmation - order uses print credits" do
    setup do
      [
        package: insert(:package, print_credits: ~M[10000]USD),
        products: build_list(1, :cart_product)
      ]
    end

    setup [:insert_gallery, :insert_order, :add_whcc_order]

    setup %{order: order} do
      insert(:intent,
        order: order,
        amount: Cart.total_cost(order),
        application_fee_amount: ~M[500]USD
      )

      [order: Repo.preload(order, :intent, force: true)]
    end

    test "includes print_credit_{used,remaining}", %{order: order} do
      assert {:ok, email} = deliver_order_confirmation(order)

      assert order
             |> shared_fields()
             |> Map.merge(%{
               print_credit_remaining: ~M[0]USD,
               print_credit_used: ~M[10000]USD,
               client_charge: ~M[53220]USD,
               photographer_payment: ~M[52720]USD,
               print_cost: ~M[500]USD
             }) ==
               template_variables(email)
    end
  end

  describe "deliver_order_confirmation - order uses print credits, photographer owes" do
    setup do
      [
        package: insert(:package, print_credits: ~M[60000]USD),
        products: build_list(1, :cart_product)
      ]
    end

    setup [:insert_gallery, :insert_order, :add_whcc_order]

    setup %{order: order} do
      insert(:invoice, order: order, amount_due: ~M[500]USD)

      [order: Repo.preload(order, :invoice, force: true)]
    end

    test "includes photographer_charge", %{order: order} do
      assert {:ok, email} = deliver_order_confirmation(order)

      assert order
             |> shared_fields()
             |> Map.merge(%{
               print_credit_remaining: ~M[7200]USD,
               print_credit_used: ~M[52800]USD,
               client_charge: ~M[0]USD,
               photographer_charge: ~M[500]USD,
               print_cost: ~M[500]USD
             }) ==
               template_variables(email)
    end
  end

  describe "deliver_order_confirmation - only digitals" do
    setup do
      [
        package: insert(:package, print_credits: ~M[100]USD),
        products: build_list(1, :digital, price: ~M[1000]USD)
      ]
    end

    setup [:insert_gallery, :insert_order]

    setup %{order: order} do
      insert(:intent, order: order, amount: Cart.total_cost(order))

      [order: Repo.preload(order, :intent, force: true)]
    end

    test "no print fields", %{order: order} do
      assert {:ok, email} = deliver_order_confirmation(order)

      assert order
             |> shared_fields()
             |> Map.merge(%{
               client_charge: ~M[1000]USD,
               photographer_payment: ~M[1000]USD
             }) ==
               template_variables(email)
    end
  end
end
