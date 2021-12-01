defmodule Picsello.WHCC.Client do
  use Tesla
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.BaseUrl, config() |> Keyword.get(:url))
  plug(Tesla.Middleware.Logger)
  alias Picsello.WHCC

  @moduledoc "client for whcc http api"
  @behaviour WHCC.Adapter

  defmodule TokenStore do
    use Agent
    @moduledoc false

    def start_link(_), do: Agent.start_link(fn -> nil end, name: __MODULE__)

    def get_and_update(f), do: Agent.get_and_update(__MODULE__, f)
  end

  def token(get_and_update \\ &TokenStore.get_and_update/1) do
    get_and_update.(fn state ->
      with %{expires_at: expires_at, token: token} <- state,
           false <- expired?(expires_at) do
        {token, state}
      else
        _ ->
          %{token: token} = state = fetch_token()
          {token, state}
      end
    end)
  end

  def designs do
    {:ok, %{body: body}} = new() |> get("/designs")
    body |> Enum.map(&WHCC.Design.from_map/1)
  end

  def products do
    {:ok, %{body: body}} = new() |> get("/products")
    body |> Enum.map(&WHCC.Product.from_map/1)
  end

  def design_details(%WHCC.Design{id: id} = design) do
    {:ok,
     %{
       body: api
     }} = new() |> get("/designs/#{id}")

    WHCC.Design.add_details(design, api)
  end

  def product_details(%WHCC.Product{id: id} = product) do
    {:ok, %{body: api}} = new() |> get("/products/#{id}")

    WHCC.Product.add_details(product, api)
  end

  def new() do
    Tesla.client([{Tesla.Middleware.BearerAuth, token: token()}])
  end

  defp fetch_token() do
    {:ok, %{body: %{"accessToken" => token, "expires" => expires_unix_time}}} =
      post(
        "/auth/access-token",
        config() |> Keyword.take([:key, :secret]) |> Enum.into(%{})
      )

    %{token: token, expires_at: DateTime.from_unix!(expires_unix_time)}
  end

  defp expired?(expires_at) do
    DateTime.compare(DateTime.utc_now(), expires_at) in [:eq, :gt]
  end

  defp config, do: Application.get_env(:picsello, :whcc)
end
