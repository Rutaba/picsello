defmodule Mix.Tasks.ProductsShippingUpcharge do
  @moduledoc false

  use Mix.Task

  alias Picsello.{Repo, Product}
  alias Ecto.Multi
  require Logger

  @values %{
    "DvnWeF5RbpGYFC8fY" => %{"default" => 20},
    "SQA2FbQuq3sFKTMFE" => %{"default" => 20},
    "DkCRPMJEWy9yieTEo" => %{"default" => 25},
    "BBrgfCJLkGzseCdds" => %{
      "default" => 13,
      "lustre" => %{
        "4x6" => 125,
        "5x5" => 155,
        "5x7" => 57,
        "8x10" => 33,
        "8x12" => 70
      }
    },
    "aeAXpFbKeRbvzGxxs" => %{"default" => 20},
    "xSYvHy3Cdm7FnFz45" => %{"default" => 5},
    "drm8DGr5Nd6NW8m3x" => %{"default" => 20},
    "pK5dANRY8HjNTMs8o" => %{"default" => 5},
    "ikNaYPvMQ3BAE5d8s" => %{"default" => 0},
    "R8vHegM2bgiYSgkDJ" => %{"default" => 20},
    "RrKCwu4G4kdQXiXum" => %{"default" => 20},
    "fY596j4wC5syHKnyF" => %{"default" => 20},
    "f5QQgHg9mAEom37bQ" => %{"default" => 10},
    "8xo9ktcm4i3XL7u66" => %{"default" => 20}
  }

  @shortdoc "add shipping upchrage"
  def run(_) do
    load_app()

    Product
    |> Repo.all()
    |> Enum.reduce(Multi.new(), fn %{whcc_id: whcc_id} = product, multi ->
      attrs = %{"shipping_upcharge" => @values[whcc_id] || %{}}
      Multi.update(multi, whcc_id, changeset(product, attrs))
    end)
    |> Repo.transaction()
    |> tap(fn {:ok, _} = x -> x end)
  end

  def changeset(%Product{} = product, attrs),
    do: Ecto.Changeset.cast(product, attrs, [:shipping_upcharge])

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
