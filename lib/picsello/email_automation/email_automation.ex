defmodule Picsello.EmailAutomation.EmailAutomation do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(lead job gallery general)a
  
  schema "email_automations" do
    field :name, :string
    field :type, Ecto.Enum, values: @types
    
    timestamps type: :utc_datetime
  end

  def changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(attrs, ~w[type name]a)
    |> validate_required(~w[type name]a)
  end
end
