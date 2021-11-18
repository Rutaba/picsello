defmodule Picsello.Workers.SyncWHCCCatalog do
  @moduledoc false
  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  @impl Oban.Worker
  def perform(_), do: Picsello.WHCC.sync()
end
