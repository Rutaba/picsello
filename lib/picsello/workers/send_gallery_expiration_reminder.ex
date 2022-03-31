defmodule Picsello.Workers.SendGalleryExpirationReminder do
  @moduledoc false
  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  @impl Oban.Worker
  def perform(_), do: Picsello.GalleryExpirationReminder.deliver_all()
end
