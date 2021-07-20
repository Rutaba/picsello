for app <- [:ex_machina, :wallaby], do: {:ok, _} = Application.ensure_all_started(app)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Picsello.Repo, :manual)
Picsello.Sandbox.PidMap.start()

Application.put_env(:wallaby, :base_url, PicselloWeb.Endpoint.url())
Stripe.StripeMock.start_link()
