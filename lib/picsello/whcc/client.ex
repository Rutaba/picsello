defmodule Picsello.WHCC.Client do
  use Tesla
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.BaseUrl, config() |> Keyword.get(:url))
  plug(Tesla.Middleware.Logger)

  alias Picsello.WHCC

  @from_address %{
    "name" => "Returns Department",
    "addr1" => "3432 Denmark Ave",
    "addr2" => "Suite 390",
    "city" => "Eagan",
    "state" => "MN",
    "zip" => "55123",
    "country" => "US"
  }

  @moduledoc "client for whcc http api"
  @behaviour WHCC.Adapter

  defmodule TokenStore do
    use Agent
    @moduledoc false

    def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

    def get_and_update(f), do: Agent.get_and_update(__MODULE__, f)
  end

  def token(key, get_and_update \\ &TokenStore.get_and_update/1) do
    get_and_update.(fn state ->
      with %{expires_at: expires_at, token: token} <- state[key],
           false <- expired?(expires_at) do
        {token, state}
      else
        _ ->
          %{token: token} = token_info = fetch_token(key)
          {token, Map.put(state, key, token_info)}
      end
    end)
  end

  @impl WHCC.Adapter
  def designs do
    {:ok, %{body: body}} = new() |> get("/designs")
    body |> Enum.map(&WHCC.Design.from_map/1)
  end

  @impl WHCC.Adapter
  def products do
    {:ok, %{body: body}} = new() |> get("/products")
    body |> Enum.map(&WHCC.Product.from_map/1)
  end

  @impl WHCC.Adapter
  def design_details(%WHCC.Design{id: id} = design) do
    if designs_enabled?() do
      {:ok,
       %{
         body: api
       }} = new() |> get("/designs/#{id}")

      WHCC.Design.add_details(design, api)
    else
      design
    end
  end

  @impl WHCC.Adapter
  def editor(%{"userId" => account_id} = params) do
    {:ok, %{body: body}} =
      new(account_id)
      |> post("/editors", params)

    body |> WHCC.CreatedEditor.from_map()
  end

  @impl WHCC.Adapter
  def get_existing_editor(account_id, editor_id) do
    {:ok, %{body: %{"url" => url}}} =
      new(account_id)
      |> post("/editors/#{editor_id}/edit-link", %{})

    WHCC.CreatedEditor.build(editor_id, url)
  end

  @impl WHCC.Adapter
  def editor_details(account_id, id) do
    {:ok, %{body: body}} = new(account_id) |> get("/editors/#{id}")

    body
    |> WHCC.Editor.Details.new()
  end

  @impl WHCC.Adapter
  def editor_clone(account_id, editor_id) do
    {:ok, %{body: %{"_id" => clone_id}}} =
      new(account_id)
      |> post("/editors/#{editor_id}/clone", %{})

    clone_id
  end

  @impl WHCC.Adapter
  def editors_export(account_id, editors, opts \\ []) do
    opts = Keyword.update(opts, :address, nil, &format_address/1)

    params =
      for {option_key, param_key} <- [
            entry_id: "entryId",
            reference: "reference",
            address: "shipToAddress"
          ],
          reduce: %{
            "editors" => editors
          } do
        params ->
          case Keyword.get(opts, option_key) do
            nil -> params
            value -> Map.put(params, param_key, value)
          end
      end
      |> case do
        %{"shipToAddress" => _} = params ->
          Map.put(params, "shipFromAddress", @from_address)

        params ->
          params
      end

    {:ok, %{body: body}} =
      account_id
      |> new()
      |> put("/oas/editors/export", params)

    body |> WHCC.Editor.Export.new()
  end

  defp format_address(%{name: name, address: address}),
    do: address |> Map.from_struct() |> Map.put(:name, name)

  @impl WHCC.Adapter
  def create_order(account_id, %WHCC.Editor.Export{order: order}) do
    {:ok, %{body: body}} =
      account_id
      |> new()
      |> post("/oas/orders/create", order)

    WHCC.Order.Created.new(body)
  end

  @impl WHCC.Adapter
  def confirm_order(account_id, confirmation) do
    {:ok, %{body: body}} =
      account_id
      |> new()
      |> post("/oas/orders/#{confirmation}/confirm", %{})

    body
    |> then(fn
      %{"ConfirmationID" => ^confirmation} -> {:ok, :confirmed}
      %{"ErrorNumber" => "412.04"} -> {:ok, :already_confirmed}
      x -> {:error, x}
    end)
  end

  @impl WHCC.Adapter
  def product_details(%WHCC.Product{id: id} = product) do
    {:ok, %{body: api}} = new() |> get("/products/#{id}")

    WHCC.Product.add_details(product, api)
  end

  @impl WHCC.Adapter
  def webhook_register(url) do
    {:ok, %{body: body}} =
      new()
      |> post("/webhooks/create", %{
        "callbackUri" => url
      })

    case body do
      %{"created" => _} ->
        :ok

      %{"error" => _, "message" => message} ->
        {:error, message}

      x ->
        {:error, x}
    end
  end

  @impl WHCC.Adapter
  def webhook_verify(hash) do
    {:ok, %{body: body}} =
      new()
      |> post("/webhooks/verify", %{"verifier" => hash})

    body
  end

  @impl WHCC.Adapter
  def webhook_validate(playload, signature) do
    {:ok, %{body: body}} =
      new()
      |> post("/webhooks/validate", %{
        "body" => playload,
        "signature" => signature
      })

    body
  end

  def new(key \\ nil) do
    Tesla.client([{Tesla.Middleware.BearerAuth, token: token(key)}])
  end

  defp fetch_token(account_id) do
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

  defp expired?(expires_at) do
    DateTime.compare(DateTime.utc_now(), expires_at) in [:eq, :gt]
  end

  defp designs_enabled?,
    do:
      Enum.member?(Application.get_env(:picsello, :feature_flags, []), :sync_whcc_design_details)

  defp config, do: Application.get_env(:picsello, :whcc)
end
