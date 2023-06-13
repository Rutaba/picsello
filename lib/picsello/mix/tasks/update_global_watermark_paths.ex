defmodule Mix.Tasks.UpdateGlobalWatermarkPaths do
  @moduledoc false

  use Mix.Task
  import Ecto.Query, only: [from: 2]
  alias Picsello.Repo
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Picsello.Galleries.{Gallery, Workers.PhotoStorage, Watermark}

  @shortdoc "update global watermark paths"
  def run(_) do
    load_app()

    from(g in Gallery,
      where: fragment("? ->> ? = 'true'", g.use_global, ^"watermark"),
      preload: :photographer
    )
    |> Repo.all()
    |> then(fn galleries ->
      Task.async_stream(
        galleries,
        fn %{id: id, photographer: %{organization_id: organization_id}} ->
          organization_id
          |> GSGallery.watermark_path()
          |> PhotoStorage.get_binary()
          |> upload_with_new_path(id)
        end,
        timeout: 15_000
      )
    end)
    |> Enum.each(& &1)
  end

  defp upload_with_new_path({:ok, %{body: body, status: 200}}, id) do
    {:ok, _} = id |> Watermark.watermark_path() |> PhotoStorage.insert(body)
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
