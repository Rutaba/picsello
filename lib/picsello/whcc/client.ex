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
    if Keyword.get(config(), :skip_design_details) do
      design
    else
      {:ok,
       %{
         body: api
       }} = new() |> get("/designs/#{id}")

      WHCC.Design.add_details(design, api)
    end
  end

  def editor(%{"userId" => account_id} = params) do
    {:ok, %{body: body}} =
      new(account_id)
      |> post("/editors", params)

    body |> WHCC.CreatedEditor.from_map()
  end

  def editor_details(account_id, id) do
    {:ok, %{body: body}} = new(account_id) |> get("/editors/#{id}")

    body
    |> WHCC.Editor.Details.new()
  end

  def editor_export(account_id, id) when not is_list(id), do: editor_export(account_id, [id])

  def editor_export(account_id, ids) do
    params =
      ids
      |> Enum.map(&%{"editorId" => &1})
      |> then(&%{"editors" => &1})

    {:ok, %{body: body}} =
      account_id
      |> new()
      |> put("/oas/editors/export", params)

    body |> WHCC.Editor.Export.new()
  end

  def create_order(account_id, editor_id, opts) do
    params =
      account_id
      |> editor_export(editor_id)
      |> WHCC.Order.Params.from_export(opts)

    {:ok, %{body: body}} =
      account_id
      |> new()
      |> post("/oas/orders/create", params)

    body |> WHCC.Order.Created.new()
  end

  def confirm_order(account_id, confirmation) do
    {:ok, %{body: body}} =
      account_id
      |> new()
      |> post("/oas/orders/#{confirmation}/confirm", %{})

    body
    |> then(fn
      %{"ConfirmationID" => ^confirmation} -> :confirmed
      %{"ErrorNumber" => "412.04"} -> :already_confirmed
      x -> {:error, x}
    end)
  end

  def product_details(%WHCC.Product{id: id} = product) do
    {:ok, %{body: api}} = new() |> get("/products/#{id}")

    WHCC.Product.add_details(product, api)
  end

  def new() do
    Tesla.client([{Tesla.Middleware.BearerAuth, token: token()}])
  end

  def new(account_id) do
    Tesla.client([{Tesla.Middleware.BearerAuth, token: fetch_token!(account_id)}])
  end

  defp fetch_token(account_id \\ nil) do
    {:ok, %{body: %{"accessToken" => token, "expires" => expires_unix_time}}} =
      post(
        "/auth/access-token",
        token_params(account_id)
      )

    %{token: token, expires_at: DateTime.from_unix!(expires_unix_time)}
  end

  defp token_params(nil), do: config() |> Keyword.take([:key, :secret]) |> Enum.into(%{})

  defp token_params(account_id) do
    token_params(nil)
    |> Map.merge(%{claims: %{"accountId" => account_id}})
  end

  defp fetch_token!(account_id) do
    account_id
    |> fetch_token()
    |> Map.get(:token)
  end

  defp expired?(expires_at) do
    DateTime.compare(DateTime.utc_now(), expires_at) in [:eq, :gt]
  end

  defp config, do: Application.get_env(:picsello, :whcc)
end
