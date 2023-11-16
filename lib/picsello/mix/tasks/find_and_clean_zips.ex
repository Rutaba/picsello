defmodule Mix.Tasks.CleanZipFilesFromCloudStorage do
  @moduledoc """
  This module defines a Mix task for deleting all zip files from the google cloud in the Picsello application.
  It is used to A) bulk clean up all zipfiles to keep storage costs low and B) to fix erroneously packed zipfiles

  To use this task, run `mix clean_zip_files_from_cloud_storage`.
  """

  use Mix.Task

  require Logger
  alias Picsello.{Repo, Organization, Galleries.Gallery, Job, Client, Pack, Workers.PackDigitals}
  import Ecto.Query

  @shortdoc "delete zipfiles if they exist across the system for orders, galleries, and albums"
  def run(_) do
    load_app()

    find_all_orgs_and_delete_zips_from_cloud_storage()
  end

  def find_all_orgs_and_delete_zips_from_cloud_storage() do
    from(o in Organization, select: %{id: o.id})
    |> Repo.all()
    |> Enum.each(fn org ->
      get_all_galleries_for_org(org.id)
      |> Enum.each(fn gallery ->
        delete_single_zip(gallery, :gallery, org.id)

        if Enum.any?(gallery.orders) do
          delete_each_zip(gallery.orders, :order, org.id)
        end

        if Enum.any?(gallery.albums) do
          delete_each_zip(gallery.albums, :album, org.id)
        end
      end)
    end)
  end

  defp get_all_galleries_for_org(organization_id) do
    from(g in Gallery,
      join: j in Job,
      on: j.id == g.job_id,
      join: c in Client,
      as: :c,
      on: c.id == j.client_id,
      preload: [:albums, [job: :client, orders: :gallery]],
      where: c.organization_id == ^organization_id
    )
    |> Repo.all()
  end

  defp delete_each_zip(array, type, organization_id),
    do: Enum.each(array, &delete_single_zip(&1, type, organization_id))

  defp delete_single_zip(struct, type, organization_id) do
    struct
    |> Pack.url()
    |> case do
      {:ok, _url} ->
        Pack.delete(struct)

        Logger.info(
          "[Info] For org_id: #{organization_id} -> #{type} #{struct.id} deleted zipfile"
        )

      {:error, _} ->
        PackDigitals.cancel(struct)

        Logger.info(
          "[Info] For org_id: #{organization_id} -> #{type} #{struct.id} does not contain zip file"
        )
    end
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
