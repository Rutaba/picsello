defmodule Picsello.PreferredFilter do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Organization, Repo}

  defmodule Filters do
    @moduledoc false
    use Ecto.Schema
    @primary_key false

    embedded_schema do
      field(:job_type, :string)
      field(:job_status, :string)
      field(:sort_by, :string)
      field(:sort_direction, :string)
      field(:event_status, :string)
    end

    def changeset(filters, attrs) do
      filters
      |> cast(attrs, [
        :job_type,
        :job_status,
        :sort_by,
        :sort_direction,
        :event_status
      ])
    end
  end

  schema "preferred_filters" do
    field(:type, :string)
    embeds_one(:filters, Filters, on_replace: :update)

    belongs_to(:organization, Organization)

    timestamps()
  end

  @fields ~w(type organization_id)a

  def changeset(preferred_filter, attrs \\ %{}) do
    preferred_filter
    |> cast(attrs, @fields)
    |> cast_embed(:filters)
    |> validate_required(@fields)
  end

  def load_preferred_filters(organization_id, type),
    do: Repo.get_by(__MODULE__, organization_id: organization_id, type: type)
end
