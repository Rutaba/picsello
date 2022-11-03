defmodule Picsello.Repo.Migrations.AddOrganizationCardTable do
  use Ecto.Migration

  alias Picsello.Repo

  import Ecto.Query, only: [from: 2]
  @order_filtered_days 7

  def up do
    execute("CREATE TYPE organization_card_status AS ENUM ('active','viewed','inactive')")

    create table(:organization_cards) do
      add(:status, :organization_card_status)
      add(:data, :jsonb)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)
      add(:card_id, references(:cards, on_delete: :nothing), null: false)

      timestamps()
    end

    flush()

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    orders =
      from(o in Order,
        where:
          not is_nil(o.album_id) and o.inserted_at > ago(@order_filtered_days, "day") and
            not is_nil(o.placed_at)
      )
      |> Repo.all()

    cards = Repo.all(Card)

    Organization
    |> Repo.all()
    |> Repo.preload(clients: [jobs: [:gallery]])
    |> Enum.reduce([], fn %{clients: clients, id: organization_id}, acc ->
      order_ids =
        clients
        |> Enum.map(&Gallery.id/1)
        |> Enum.concat()
        |> Enum.reject(&is_nil/1)
        |> then(fn gallery_ids ->
          orders
          |> Enum.filter(&(&1.gallery_id in gallery_ids))
          |> Enum.map(fn order -> order.id end)
        end)

      acc ++
        for card <- cards, reduce: [] do
          acc ->
            case card do
              %{concise_name: "proofing-album-order"} ->
                for order_id <- order_ids do
                  Card.organization_card(card, organization_id, now, %{order_id: order_id})
                end ++ acc

              _ ->
                [Card.organization_card(card, organization_id, now) | acc]
            end
        end
    end)
    |> then(&Picsello.Repo.insert_all("organization_cards", &1))
  end

  def down do
    drop(table(:organization_cards))
    execute("DROP TYPE organization_card_status")
  end
end

defmodule Organization do
  use Ecto.Schema

  schema "organizations" do
    has_many(:clients, Client)
  end
end

defmodule Client do
  use Ecto.Schema

  schema "clients" do
    belongs_to(:organization, Organization)
    has_many(:jobs, Job)
  end
end

defmodule Job do
  use Ecto.Schema

  schema "jobs" do
    belongs_to(:client, Client)
    has_one(:gallery, Gallery)
  end
end

defmodule Gallery do
  use Ecto.Schema

  schema "galleries" do
    belongs_to(:job, Job)
  end

  def id(%{jobs: jobs}), do: Enum.map(jobs, &id(&1))
  def id(%{gallery: %{id: id}}), do: id
  def id(_), do: nil
end

defmodule Album do
  use Ecto.Schema

  schema "albums" do
  end
end

defmodule Card do
  use Ecto.Schema

  schema "cards" do
    field :concise_name, :string
  end

  def organization_card(card, organization_id, now, data \\ %{}) do
    %{
      card_id: card.id,
      organization_id: organization_id,
      status: "active",
      inserted_at: now,
      updated_at: now,
      data: data
    }
  end
end

defmodule Order do
  use Ecto.Schema

  schema "gallery_orders" do
    belongs_to(:album, Album)
    belongs_to(:gallery, Gallery)
  end
end
