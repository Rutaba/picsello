defmodule Picsello.WHCC.Client do
  use Tesla
  alias Picsello.WHCC.Category
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.BaseUrl, config() |> Keyword.get(:url))
  plug(Tesla.Middleware.Logger)

  @moduledoc "client for whcc http api"
  @behaviour Picsello.WHCC.Adapter

  defmodule TokenStore do
    use Agent
    @moduledoc false

    def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

    def get_and_update(f), do: Agent.get_and_update(__MODULE__, f)
  end

  def token() do
    update =
      &case &1 do
        %{fetched_at: fetched_at} ->
          if expired?(fetched_at) do
            fetch_token()
          else
            &1
          end

        %{} ->
          fetch_token()
      end

    TokenStore.get_and_update(fn state ->
      %{token: token} = state = update.(state)
      {token, state}
    end)
  end

  def products() do
    {:ok, %{body: body}} = new() |> get("/products")
    body
  end

  @impl true
  def categories() do
    products()
    |> Enum.map(&Map.get(&1, "category"))
    |> Enum.uniq()
    |> Enum.map(&%Category{id: &1["id"], name: &1["name"]})
  end

  def new() do
    Tesla.client([{Tesla.Middleware.BearerAuth, token: token()}])
  end

  defp fetch_token() do
    {:ok, %{body: %{"accessToken" => token, "expires" => fetched_at}}} =
      post(
        "/auth/access-token",
        config() |> Keyword.take([:key, :secret]) |> Enum.into(%{})
      )

    %{token: token, fetched_at: DateTime.from_unix!(fetched_at)}
  end

  defp expired?(fetched_at) do
    expires_at = DateTime.add(fetched_at, Keyword.get(config(), :token_valid_for))
    now = DateTime.utc_now()
    DateTime.compare(expires_at, now) != :gt
  end

  defp request_start(%Tesla.Env{headers: headers}) do
    with {request_start_ms, ""} <-
           headers
           |> Enum.find_value("0", fn {k, v} -> k == "x-request-start" && v end)
           |> Integer.parse(),
         {:ok, request_start} <- request_start_ms |> div(1000) |> DateTime.from_unix() do
      request_start
    end
  end

  defp config, do: Application.get_env(:picsello, :whcc_client)
end
