defmodule Picsello.AdminGlobalSettings do
  @moduledoc "context module for admin global settings"

  import Ecto.Query, warn: false

  alias Picsello.{Repo, AdminGlobalSetting}

  @doc """
  Gets admin global setting by slug.

  Returns nil if the admin global setting does not exist.
  """
  def get_settings_by_slug(slug) do
    Repo.get_by(AdminGlobalSetting, slug: slug)
  end

  @doc """
  Gets active admin global settings.

  Returns [] if the admin global settings does not exist.
  """
  def get_all_active_settings() do
    from(ags in AdminGlobalSetting, where: ags.status == :active)
    |> Repo.all()
  end

  def insert_setting(setting) do
    %AdminGlobalSetting{}
    |> AdminGlobalSetting.changeset(setting)
    |> Repo.insert()
  end

  def delete_setting(setting), do: setting |> Repo.delete()
end
  