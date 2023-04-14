defmodule Mix.Tasks.UpdateGlobalWatermarkPaths do
  @moduledoc false

  use Mix.Task
  import Ecto.Query, only: [from: 2]
  alias Picsello.Repo
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Picsello.Galleries.{Workers.PhotoStorage, Watermark}

  @shortdoc "update global watermark paths"
  def run(_) do
    load_app()

    from(gs in GSGallery,
      where: gs.watermark_type == :image,
      preload: [:organization]
    )
    |> Repo.all()
    |> then(fn gs_galleries ->
      Task.async_stream(
        gs_galleries,
        fn %{id: ggs_id, organization: %{id: organization_id}} ->
          organization_id
          |> Watermark.watermark_path()
          |> PhotoStorage.get_binary()
          |> upload_with_new_path(ggs_id, organization_id)
        end,
        timeout: 15_000
      )
    end)
    |> Enum.each(& &1)
  end

  defp upload_with_new_path({:ok, %{body: body, status: 200}}, ggs_id, org_id) do
    {:ok, _} = ggs_id |> GSGallery.watermark_path() |> PhotoStorage.insert(body)
    :ok = org_id |> Watermark.watermark_path() |> PhotoStorage.delete()
  end

  defp upload_with_new_path(_resp, _ggs_id, _org_id), do: :ok

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
