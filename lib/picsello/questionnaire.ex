defmodule Picsello.Questionnaire do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Questionaire.Question, Job}

  defmodule Question do
    @moduledoc false

    use Ecto.Schema

    embedded_schema do
      field(:prompt, :string)
      field(:type, Ecto.Enum, values: [:text, :select, :date, :multiselect, :phone, :email])
      field(:optional, :boolean)
      field(:options, {:array, :string})
    end

    def changeset(question, attrs) do
      question
      |> cast(attrs, [:prompt, :type, :optional, :options])
    end
  end

  schema "questionnaires" do
    embeds_many(:questions, Question)
    field(:job_type, :string)

    timestamps()
  end

  @doc false
  def changeset(questionnaire, attrs) do
    questionnaire
    |> cast(attrs, [:job_type])
    |> cast_embed(:questions, required: true)
    |> validate_required([:questions, :job_type])
    |> foreign_key_constraint(:job_type)
  end

  def for_job(%Job{type: job_type}) do
    from(q in __MODULE__, where: q.job_type == ^job_type)
  end
end
