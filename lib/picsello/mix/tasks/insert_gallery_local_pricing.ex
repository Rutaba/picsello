defmodule Mix.Tasks.InsertGalleryLocalPricing do
  @moduledoc false

  use Mix.Task
  alias Picsello.{Repo, Galleries.Gallery}

  @shortdoc "insert global local settings"
  def run(_) do
    load_app()

    galleries =
      Gallery
      |> Repo.all()
      |> Repo.preload([:gallery_digital_pricing, job: [:client, :package]])

    Enum.map(galleries, fn gallery ->
      if is_nil(gallery.gallery_digital_pricing),
      do:
        Gallery.save_digital_pricing_changeset(gallery, %{gallery_digital_pricing: %{
          download_each_price:
            if(gallery.job.package,
              do: gallery.job.package.download_each_price,
              else: Money.new(5000)
            ),
          download_count: if(gallery.job.package, do: gallery.job.package.download_count, else: 0),
          buy_all: if(gallery.job.package, do: gallery.job.package.buy_all, else: Money.new(0)),
          print_credits:
            if(gallery.job.package, do: gallery.job.package.print_credits, else: Money.new(0)),
          email_list: [gallery.job.client.email]
        }})
        |> Repo.update!()
      end)
    end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
