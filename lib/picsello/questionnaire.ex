defmodule Picsello.Questionnaire do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Job, Repo}

  defmodule Question do
    @moduledoc false

    use Ecto.Schema

    embedded_schema do
      field(:prompt, :string)
      field(:placeholder, :string)

      field(:type, Ecto.Enum,
        values: [:text, :textarea, :select, :date, :multiselect, :phone, :email]
      )

      field(:optional, :boolean)
      field(:options, {:array, :string})
    end

    def changeset(question, attrs) do
      question
      |> cast(attrs, [:prompt, :placeholder, :type, :optional, :options])
    end
  end

  schema "questionnaires" do
    embeds_many(:questions, Question, on_replace: :delete)
    field(:job_type, :string)
    field(:name, :string)
    field(:is_organization_default, :boolean)
    field(:is_picsello_default, :boolean)
    belongs_to :organization, Picsello.Organization

    timestamps()
  end

  @doc false
  def changeset(questionnaire, attrs) do
    questionnaire
    |> cast(attrs, [
      :job_type,
      :name,
      :organization_id,
      :is_organization_default,
      :is_picsello_default
    ])
    |> cast_embed(:questions, required: true)
    |> validate_required([:questions, :job_type, :name])
  end

  def for_job(%Job{type: job_type}) do
    from(q in __MODULE__,
      where: q.job_type in [^job_type, "other"],
      order_by:
        fragment(
          """
          case
            when ?.job_type != 'other' then 0
            when ?.job_type = 'other' then 1
          end asc
          """,
          q,
          q
        ),
      limit: 1
    )
  end

  def all() do
    from(q in __MODULE__)
    |> Repo.all()
  end

  def for_organization(organization_id) do
    from(q in __MODULE__,
      where: q.organization_id == ^organization_id,
      order_by: [asc: q.organization_id, desc: q.inserted_at]
    )
    |> Repo.all()
  end

  def delete_one(questionnaire_id) do
    from(q in __MODULE__, where: q.id == ^questionnaire_id)
    |> Repo.delete_all()
  end

  def get_one(questionnaire_id) do
    from(q in __MODULE__, where: q.id == ^questionnaire_id) |> Repo.one()
  end
end
