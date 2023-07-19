defmodule Picsello.Currency do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query
  alias Picsello.Repo

  @default_currency "USD"

  @primary_key {:code, :string, []}
  schema "currencies" do
  end

  def search(search_term) do
    from(c in __MODULE__,
      where: ilike(c.code, ^"#{search_term}%")
    )
    |> Repo.all()
  end

  def default_currency(), do: @default_currency

  @doc """
  Iterate over map to convert price values 'having currency symbol' to %Money{}.
  For example:

  iex> parse_params_for_currency(%{"price" => "$12"}, {"$", "USD"})
  %{"price" => Money{amount: 12, currency: :USD}}
  """

  @spec parse_params_for_currency(map(), {binary(), binary()}) :: map()
  def parse_params_for_currency(value, {symbol, code}) when is_map(value),
    do: value |> symbol_to_code({symbol, code}) |> Map.put("parsed?", "yes")

  defp symbol_to_code(%{} = map, opts) do
    map
    |> Enum.map(fn {key, value} -> {key, symbol_to_code(value, opts)} end)
    |> Map.new()
  end

  defp symbol_to_code([_ | _] = value, opts), do: Enum.map(value, &symbol_to_code(&1, opts))

  defp symbol_to_code("" <> value, {symbol, _} = opts) do
    case String.starts_with?(value, symbol) do
      true -> convert(value, opts)
      false -> value
    end
  end

  defp symbol_to_code(value, _opts), do: value

  defp convert(symbol, {symbol, currency}), do: build(0, currency)

  defp convert(value, {symbol, currency}) do
    value
    |> String.replace([symbol, ","], "")
    |> Float.parse()
    |> then(fn
      {float, ""} ->
        float
        |> Kernel.*(100)
        |> round()
        |> build(currency)

      _ ->
        value
    end)
  end

  defp build(amount, currency),
    do: %Money{
      amount: amount,
      currency: (is_binary(currency) && String.to_existing_atom(currency)) || currency
    }

  def for_order(order) do
    %{package: %{currency: currency}} = Repo.preload(order, gallery: :package)
    currency
  end

  def for_job(job) do
    %{package: %{currency: currency}} = Repo.preload(job, :package)
    currency
  end

  def for_gallery(gallery) do
    %{package: %{currency: currency}} = Repo.preload(gallery, :package)
    currency
  end
end
