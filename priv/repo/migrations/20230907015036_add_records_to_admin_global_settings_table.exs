defmodule Picsello.Repo.Migrations.AlterAdminSettingsTable do
  use Ecto.Migration

  def change do
    [
      {"email_to limit", "number of emails that can be added in 'to' field", "to_limit", "1"},
      {"email_bcc limit", "number of emails that can be added in 'bcc' field", "bcc_limit", "10"},
      {"email_bcc limit", "number of emails that can be added in 'bcc' field", "bcc_limit", "10"}
    ]
    |> Enum.each(fn {title, description, slug, value} ->
      execute("""
        INSERT INTO admin_global_settings
          (title, description, slug, value, status, updated_at, inserted_at)
        VALUES
          ('#{title}', '#{description}', '#{slug}', '#{value}', 'active', now(), now());
      """)
    end)
  end
end
