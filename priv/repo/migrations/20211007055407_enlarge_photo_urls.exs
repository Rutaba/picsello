defmodule Picsello.Repo.Migrations.EnlargePhotoUrls do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      modify(:original_url, :text)
      modify(:preview_url, :text)
      modify(:client_copy_url, :text)
      modify(:watermarked_url, :text)
    end
  end
end
