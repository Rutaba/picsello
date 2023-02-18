defmodule Picsello.Repo.Migrations.UpdateProductOrders do
  use Ecto.Migration

  alias Ecto.Multi
  alias Picsello.Repo
  alias Ecto.Changeset

  import Ecto.Query

  def change do
    from(order in Order, where: not is_nil(order.whcc_order))
    |> Repo.all()
    |> Enum.filter(& &1.whcc_order["orders"])
    |> Enum.reduce(Multi.new(), fn %{whcc_order: %{"orders" => orders} = whcc_order} = o, multi ->
      whcc_order = Map.put(whcc_order, "orders", Enum.map(orders, &Order.update_order/1))
      Multi.update(multi, o.id, Changeset.change(o, %{whcc_order: whcc_order}))
    end)
    |> Repo.transaction()
  end
end

defmodule Order do
  use Ecto.Schema

  schema("gallery_orders", do: field(:whcc_order, :map))

  def update_order(%{"editor_id" => editor_id} = order),
    do:
      order
      |> Map.put("editor_ids", editor_ids(editor_id))
      |> Map.delete("editor_id")

  def update_order(order), do: order

  defp editor_ids(""), do: []
  defp editor_ids(nil), do: []
  defp editor_ids(editor_id), do: [editor_id]
end
