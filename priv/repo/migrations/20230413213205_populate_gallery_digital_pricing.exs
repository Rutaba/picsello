defmodule Picsello.Repo.Migrations.PopulateGalleryDigitalPricing do
  use Ecto.Migration
  import Ecto.Query

  alias Picsello.{Repo, Galleries.Gallery}

  def change do
    galleries =
      Gallery
      |> Repo.all()
      |> Repo.preload(job: [:client, :package])

    Enum.map(galleries, fn gallery ->
      digital_pricing =
        %{
          download_each_price: (if gallery.job.package, do: gallery.job.package.download_each_price, else: Money.new(5000)),
          download_count: (if gallery.job.package, do: gallery.job.package.download_count, else: 0),
          buy_all: (if gallery.job.package, do: gallery.job.package.buy_all, else: Money.new(0)),
          print_credits: (if gallery.job.package, do: gallery.job.package.print_credits, else: Money.new(0)),
          email_list: [gallery.job.client.email]
        }

      Gallery.save_digital_pricing_changeset(gallery, %{digital_pricing: digital_pricing}) |> Repo.update!()
    end)
  end
end
