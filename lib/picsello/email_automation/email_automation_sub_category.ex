defmodule Picsello.EmailAutomation.EmailAutomationSubCategory do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset

  schema "email_automation_sub_categories" do
    field :name, :string
    field(:slug, :string)

    timestamps type: :utc_datetime
  end

  def changeset(email_sub_category \\ %__MODULE__{}, attrs) do
    email_sub_category
    |> cast(attrs, ~w[slug name]a)
    |> validate_required(~w[slug name]a)
  end
end
