defmodule Mix.Tasks.UploadFile do
  @moduledoc false

  use Mix.Task
  alias Picsello.Galleries.Workers.PhotoStorage

  @global_watermark_photo ~s(assets/static/images/watermark_preview.png)

  @shortdoc "Upload file to cloud"
  def run(_) do
    load_app()

    file = File.read!(@global_watermark_photo)
    path = Application.fetch_env!(:picsello, :global_watermarked_path)
    {:ok, _object} = PhotoStorage.insert(path, file)
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
