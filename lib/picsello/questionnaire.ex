defmodule Picsello.Questionnaire do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Job, Repo, Package}

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
  def changeset(questionnaire, attrs \\ %{}, state \\ nil) do
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
    |> validate_required([:job_type, :name])
    |> validate_name(state)
    |> validate_is_picsello_default()
    |> maybe_validate_unique_name?(questionnaire)
    |> unique_constraint([:name, :organization_id])
  end

  def for_job(%Job{type: job_type, package: %Package{questionnaire_template_id: nil}}),
    do: get_default_questionnaire(job_type)

  def for_job(%Job{package: %Package{questionnaire_template_id: questionnaire_id}}),
    do: get_questionnaire(questionnaire_id)

  def for_package(%Package{questionnaire_template_id: nil, job_type: job_type}),
    do:
      get_default_questionnaire(job_type)
      |> Repo.one!()

  def for_package(%Package{questionnaire_template_id: questionnaire_id}),
    do: get_questionnaire(questionnaire_id) |> Repo.one!()

  def for_organization(organization_id) do
    get_organization_questionnaires(organization_id)
    |> Repo.all()
  end

  def for_organization_by_job_type(organization_id, nil) do
    get_organization_questionnaires(organization_id)
    |> where([q], q.job_type == "other")
    |> Repo.all()
  end

  def for_organization_by_job_type(organization_id, job_type) do
    get_organization_questionnaires(organization_id)
    |> where([q], q.job_type == ^job_type or q.job_type == "other")
    |> Repo.all()
  end

  def delete_questionnaire_by_id(questionnaire_id),
    do:
      get_questionnaire(questionnaire_id)
      |> Repo.delete_all()

  def get_questionnaire_by_id(questionnaire_id),
    do: get_questionnaire(questionnaire_id) |> Repo.one()

  def clean_questionnaire_for_changeset(
        questionnaire,
        organization_id,
        package_id \\ nil
      ) do
    questions =
      questionnaire.questions
      |> Enum.map(fn question ->
        question |> Map.from_struct() |> Map.drop([:id])
      end)

    %Picsello.Questionnaire{
      organization_id: organization_id,
      questions: questions,
      package_id: package_id,
      name: questionnaire.name,
      job_type: questionnaire.job_type
    }
  end

  defp validate_name(changeset, state) do
    name_field = get_field(changeset, :name)
    name_change = get_change(changeset, :name)
    is_picsello_default = get_field(changeset, :is_picsello_default)

    if state !== :edit_lead && !is_picsello_default && name_change &&
         String.contains?(name_field, ["Picsello", "Template", "picsello", "template"]) do
      changeset |> add_error(:name, "cannot contain 'Picsello' or 'Template'")
    else
      changeset
    end
  end

  defp validate_is_picsello_default(changeset) do
    is_picsello_default = get_field(changeset, :is_picsello_default)
    package_id = get_field(changeset, :package_id)
    organization_id = get_field(changeset, :organization_id)

    if is_picsello_default && (package_id || organization_id) do
      changeset
      |> add_error(:is_picsello_default, "cannot edit Picsello Template")
    else
      changeset
    end
  end

  defp maybe_validate_unique_name?(changeset, %{package_id: nil}) do
    changeset
    |> unsafe_validate_unique([:name, :organization_id], Repo)
  end

  defp maybe_validate_unique_name?(changeset, _) do
    changeset
  end

  defp get_organization_questionnaires(organization_id) do
    from(q in __MODULE__,
      where: q.organization_id == ^organization_id or q.is_picsello_default,
      where: is_nil(q.package_id),
      order_by: [asc: q.organization_id, desc: q.inserted_at]
    )
  end

  defp get_default_questionnaire(job_type) do
    from(q in __MODULE__,
      where: q.job_type in [^job_type, "other"],
      where: q.is_picsello_default,
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

  defp get_questionnaire(questionnaire_id),
    do: from(q in __MODULE__, where: q.id == ^questionnaire_id)
end
