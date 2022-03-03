defmodule Picsello.Mock do
  @moduledoc false

  defmodule UeberauthStrategyBehaviorPatch do
    @moduledoc "callbacks we need to mock that aren't defined in the Ueberauth.Strategy behavior"

    @callback default_options() :: keyword()
    @callback auth(Plug.Conn.t()) :: Ueberauth.Auth.t()
  end

  def all(),
    do: [
      Picsello.MockAuthStrategy,
      Picsello.MockBambooAdapter,
      Picsello.MockPayments,
      Picsello.MockWHCCClient,
      Picsello.PhotoStorageMock
    ]

  def setup do
    Mox.defmock(Picsello.MockPayments, for: Picsello.Payments)
    Mox.defmock(Picsello.MockBambooAdapter, for: Bamboo.Adapter)
    Mox.defmock(Picsello.MockWHCCClient, for: Picsello.WHCC.Adapter)
    Mox.defmock(Picsello.PhotoStorageMock, for: Picsello.Galleries.Workers.PhotoStorage)

    Mox.defmock(Picsello.MockAuthStrategy,
      for: [Ueberauth.Strategy, UeberauthStrategyBehaviorPatch]
    )
  end

  def allow_all(owner_pid, child_pid) do
    all() |> Enum.each(&Mox.allow(&1, owner_pid, child_pid))
  end

  def mock_google_sheets(range_to_tsv_map) do
    range_to_response =
      for({range, tsv} <- range_to_tsv_map) do
        response = %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "values" =>
                case tsv do
                  "" <> _tsv ->
                    tsv
                    |> String.trim()
                    |> String.split("\n")
                    |> Enum.map(&String.split(&1, "\t"))

                  [[_headers | _] | _] ->
                    tsv
                end,
              "range" => range,
              "majorDimension" => "ROWS"
            })
        }

        {range, response}
      end

    Tesla.Mock.mock(fn
      %{method: :get, url: url} ->
        path = url |> URI.parse() |> Map.get(:path) |> URI.decode()

        {_path, response} = Enum.find(range_to_response, &String.contains?(path, elem(&1, 0)))
        response
    end)
  end
end

Picsello.Mock.setup()
