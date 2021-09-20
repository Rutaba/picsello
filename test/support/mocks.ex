defmodule Picsello.UeberauthStrategyBehaviorPatch do
  @callback default_options() :: keyword()
  @callback auth(Plug.Conn.t()) :: Ueberauth.Auth.t()
end

Mox.defmock(Picsello.MockPayments, for: Picsello.Payments)
Mox.defmock(Picsello.MockBambooAdapter, for: Bamboo.Adapter)

Mox.defmock(Picsello.MockAuthStrategy,
  for: [Ueberauth.Strategy, Picsello.UeberauthStrategyBehaviorPatch]
)
