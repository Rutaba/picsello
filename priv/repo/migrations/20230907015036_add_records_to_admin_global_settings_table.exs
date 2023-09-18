defmodule Picsello.Repo.Migrations.AlterAdminSettingsTable do
  use Ecto.Migration

  def change do
    [
      {2, "To Email Limit", "Number of emails that can be added in \"to\" field", "to_limit",
       "1"},
      {3, "CC Email Limit", "Number of emails that can be added in \"cc\" field", "cc_limit",
       "10"},
      {4, "BCC Email Limit", "Number of emails that can be added in \"bcc\" field", "bcc_limit",
       "10"}
    ]
    |> Enum.each(fn {id, title, description, slug, value} ->
      execute("""
        INSERT INTO admin_global_settings VALUES (#{id}, '#{title}', '#{description}', '#{slug}', '#{value}', 'active', now(), now());
      """)
    end)
  end
end
