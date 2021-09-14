defmodule Picsello.Repo do
  use Ecto.Repo,
    otp_app: :picsello,
    adapter: Ecto.Adapters.Postgres

  use Paginator, include_total_count: true
end
