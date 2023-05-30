defmodule Picsello.EmailAutomation.EmailAutomationPipeline do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.EmailAutomation.EmailAutomation
  alias Picsello.Organization

  @status ~w(active disabled archived)a

  schema "email_automation_pipelines" do
    field :name, :string
    field :status, Ecto.Enum, values: @status, default: :active
    #please emails presets
    field :state, :string
    belongs_to(:email_automation, EmailAutomation)
    belongs_to(:organization, Organization)

    timestamps type: :utc_datetime
  end

  def changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(attrs, ~w[status state name email_automation_id organization_id]a)
    |> validate_required(~w[status state name email_automation_id organization_id]a)
  end
end
