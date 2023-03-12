defmodule Mix.Tasks.ScanWatermarks do
  @moduledoc false

  use Mix.Task
  import Ecto.Query, only: [from: 2]
  alias Ecto.Multi
  alias Picsello.{Galleries, Repo}
  alias GoogleApi.Storage.V1.Model.Object
  alias Picsello.Galleries.{Workers.PhotoStorage, Gallery, Watermark}

  @shortdoc "update galleries"
  def run(_) do
    load_app()

    from(g in Gallery,
      join: org in assoc(g, :organization),
      left_join: ggs in assoc(org, :global_setting),
      left_join: watermark in assoc(g, :watermark),
      where:
        not is_nil(ggs.id) and g.inserted_at > ggs.inserted_at and g.use_global == false and
          not is_nil(watermark.id),
      preload: [:watermark, [organization: [:global_setting]]]
    )
    |> Repo.all()
    |> then(fn galleries ->
      Task.async_stream(
        galleries,
        fn %{id: id, organization: %{global_setting: ggs}} ->
          id
          |> Watermark.watermark_path()
          |> PhotoStorage.get()
          |> check_watermark(id, ggs)
        end,
        max_concurrency: System.schedulers_online() * 3
      )
    end)
    |> Enum.to_list()
    |> Enum.reduce({[], []}, fn
      {:ok, {:exist_globally, gallery_id}}, {exist_globally, not_exist} ->
        {[gallery_id | exist_globally], not_exist}

      {:ok, {:not_exist, gallery_id}}, {exist_globally, not_exist} ->
        {exist_globally, [gallery_id | not_exist]}

      {:ok, {:exist, _}}, acc ->
        acc
    end)
    |> then(fn
      {exist_globally, not_exist} ->
        Multi.new()
        |> Multi.run(:update_exist_globally_ids, fn _, _ ->
          Galleries.update_all(exist_globally, use_global: true)

          {:ok, ""}
        end)
        |> Multi.delete_all(
          :delete_not_exist,
          from(w in Watermark, join: g in assoc(w, :gallery), where: g.id in ^not_exist)
        )
        |> Repo.transaction()
        |> tap(fn
          {:ok, _} -> Enum.each(not_exist, &Galleries.clear_watermarks(&1))
          x -> x
        end)
    end)
  end

  defp check_watermark(path, id, ggs) do
    case path do
      {:error, _} when not is_nil(ggs.watermark_name) -> {:exist_globally, id}
      {:error, _} -> {:not_exist, id}
      {:ok, %Object{}} -> {:exist, id}
    end
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
