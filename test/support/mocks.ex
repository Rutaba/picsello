defmodule Picsello.Mock do
  @moduledoc false

  defmodule UeberauthStrategyBehaviorPatch do
    @moduledoc "callbacks we need to mock that aren't defined in the Ueberauth.Strategy behavior"

    @callback default_options() :: keyword()
    @callback auth(Plug.Conn.t()) :: Ueberauth.Auth.t()
  end

  def all(), do: [Picsello.MockAuthStrategy, Picsello.MockBambooAdapter, Picsello.MockPayments]

  def setup do
    Mox.defmock(Picsello.MockPayments, for: Picsello.Payments)
    Mox.defmock(Picsello.MockBambooAdapter, for: Bamboo.Adapter)
    Mox.defmock(Picsello.MockWHCCClient, for: Picsello.WHCC.Adapter)

    Mox.defmock(Picsello.MockAuthStrategy,
      for: [Ueberauth.Strategy, UeberauthStrategyBehaviorPatch]
    )
  end

  def allow_all(owner_pid, child_pid) do
    all() |> Enum.each(&Mox.allow(&1, owner_pid, child_pid))
  end
end

Picsello.Mock.setup()
