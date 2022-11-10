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
      field(:options, {:array, :string}, default: [])
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
    field(:is_organization_default, :boolean, default: false)
    field(:is_picsello_default, :boolean, default: false)
    belongs_to :organization, Picsello.Organization
    belongs_to :package, Picsello.Package

    timestamps()
  end

  @doc false
  def changeset(questionnaire, attrs \\ %{}) do
    questionnaire
    |> cast(attrs, [
      :job_type,
      :name,
      :organization_id,
      :package_id,
      :is_organization_default,
      :is_picsello_default
    ])
    |> cast_embed(:questions, required: true)
    |> validate_required([:questions, :job_type, :name])
  end

  def for_job(%Job{type: job_type, package: %Picsello.Package{questionnaire_template_id: nil}}) do
    from(q in __MODULE__,
      where: q.job_type in [^job_type, "other"],
      where: q.is_picsello_default == true,
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

  def for_job(%Job{package: %Picsello.Package{questionnaire_template_id: questionnaire_id}}) do
    from(q in __MODULE__, where: q.id == ^questionnaire_id, limit: 1)
  end

  def for_package(%Picsello.Package{questionnaire_template_id: nil, job_type: job_type}) do
    from(q in __MODULE__,
      where: q.job_type in [^job_type, "other"],
      where: q.is_picsello_default == true,
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
    |> Repo.one!()
  end

  def for_package(%Picsello.Package{questionnaire_template_id: questionnaire_id}) do
    from(q in __MODULE__, where: q.id == ^questionnaire_id, limit: 1) |> Repo.one!()
  end

  def for_organization(organization_id) do
    from(q in __MODULE__,
      where: q.organization_id == ^organization_id or q.is_picsello_default == true,
      where: is_nil(q.package_id),
      order_by: [asc: q.organization_id, desc: q.inserted_at]
    )
    |> Repo.all()
  end

  def for_organization_by_job_type(organization_id, nil) do
    from(q in __MODULE__,
      where: q.organization_id == ^organization_id or q.is_picsello_default == true,
      where: q.job_type == "other",
      where: is_nil(q.package_id),
      order_by: [asc: q.organization_id, desc: q.inserted_at]
    )
    |> Repo.all()
  end

  def for_organization_by_job_type(organization_id, job_type) do
    from(q in __MODULE__,
      where: q.organization_id == ^organization_id or q.is_picsello_default == true,
      where: q.job_type == ^job_type or q.job_type == "other",
      where: is_nil(q.package_id),
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

  def clean_questionnaire_for_changeset(questionnaire, current_user, package_id \\ nil) do
    questions =
      questionnaire
      |> Map.get(:questions)
      |> Enum.map(fn question ->
        question |> Map.from_struct() |> Map.drop([:id])
      end)

    questionnaire
    |> Map.replace!(
      :questions,
      questions
    )
    |> Map.merge(%{
      id: nil,
      organization_id: current_user.organization_id,
      is_picsello_default: false,
      is_organization_default: false,
      inserted_at: nil,
      package_id: package_id,
      updated_at: nil,
      __meta__: %Picsello.Questionnaire{} |> Map.get(:__meta__)
    })
  end
end
