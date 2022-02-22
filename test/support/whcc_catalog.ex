defmodule Picsello.Test.WHCCCatalog do
  @moduledoc "simulate WHCC catalog calls"

  def sync_catalog do
    read_fixture =
      &("test/support/fixtures/whcc/api/v1/#{&1}.json" |> File.read!() |> Jason.decode!())

    Picsello.MockWHCCClient
    |> Mox.stub(:products, fn ->
      for(product <- read_fixture.("products"), do: Picsello.WHCC.Product.from_map(product))
    end)
    |> Mox.stub(:product_details, fn %{id: id} = product ->
      Picsello.WHCC.Product.add_details(product, read_fixture.("products/#{id}"))
    end)
    |> Mox.stub(:designs, fn ->
      for(design <- read_fixture.("designs"), do: Picsello.WHCC.Design.from_map(design))
    end)
    |> Mox.stub(:design_details, fn %{id: id} = design ->
      Picsello.WHCC.Design.add_details(design, read_fixture.("designs/#{id}"))
    end)

    Picsello.WHCC.sync()

    Picsello.Repo.update_all(Picsello.Category, set: [hidden: false])

    :ok
  end
end
