defmodule Picsello.WHCC do
  @moduledoc "WHCC context module"
  alias Picsello.{Repo, WHCC.Adapter}

  import Ecto.Query

  def sync_categories() do
    # fetch latest products from whcc api
    # upsert changes into db records
    # mark unmentioned products as deleted
    categories =
      for(
        {%Picsello.WHCC.Category{id: id, name: name}, position} <-
          Enum.with_index(Adapter.categories())
      ) do
        %{
          whcc_id: id,
          whcc_name: name,
          name: name,
          deleted_at: nil,
          position: position,
          icon: "book"
        }
      end

    Repo.transaction(fn ->
      Picsello.Category.active()
      |> Repo.update_all(set: [deleted_at: DateTime.utc_now()])

      Repo.insert_all(Picsello.Category, categories,
        conflict_target: [:whcc_id],
        on_conflict: {:replace, [:whcc_name, :deleted_at]}
      )
    end)
  end

  def categories do
    from(category in Picsello.Category.active(),
      where: not category.hidden,
      order_by: [asc: category.position]
    )
    |> Repo.all()
  end
end
