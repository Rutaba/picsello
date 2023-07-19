defmodule Picsello.EmailAutomation.EmailAutomationCategory do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.EmailAutomation.EmailAutomationPipeline
  @types ~w(lead job gallery general)a

  schema "email_automation_categories" do
    field :name, :string
    field :type, Ecto.Enum, values: @types
    has_many(:email_automation_pipleines, EmailAutomationPipeline)
  end

  def changeset(email_category \\ %__MODULE__{}, attrs) do
    email_category
    |> cast(attrs, ~w[type name]a)
    |> validate_required(~w[type name]a)
  end
end
