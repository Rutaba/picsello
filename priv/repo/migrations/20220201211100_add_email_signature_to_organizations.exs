defmodule Picsello.Repo.Migrations.AddEmailSignatureToOrganizations do
  use Ecto.Migration

  def change do
    alter table("organizations") do
      add(:email_signature, :map, default: fragment("'{\"show_fone\": true}'::jsonb"))
    end
  end
end
