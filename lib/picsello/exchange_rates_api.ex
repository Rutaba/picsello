defmodule Picsello.ExchangeRatesApi do
  @moduledoc """
  The exchange rates api adapter.
  """
  require Logger

  def url() do
    Application.get_env(:picsello, :exchange_rates) |> Keyword.get(:url)
  end

  def access_key() do
    Application.get_env(:picsello, :exchange_rates) |> Keyword.get(:access_key)
  end

  @doc """
    gets latest exchange rate of base currency to different currencies
    For example:
    iex> get_latest_rate("USD, "EUR")
    {:ok, %{"base" => "USD", "date" => "2023-06-30", "rates" => %{"EUR" => 0.91655}, "success" => true, "timestamp" => 1688158263}}
  """
  def get_latest_rate(base_currency, to_currency) do
    params = [base: base_currency, symbols: to_currency]
    url = url() <> "/latest"
    {:ok, %{"rates" => rates}} = api_callback(url, params)
    Map.get(rates, to_currency)
  end

  @doc """
    converts from one currency to another currency
    For example:
    iex> get_latest_rate("USD, "EUR", 25)
    {:ok, %{"date" => "2023-06-30", "info" => %{"rate" => 0.91605, "timestamp" => 1688160124}, "query" => %{"amount" => 25, "from" => "USD", "to" => "EUR"}, "result" => 22.90125, "success" => true}}
  """
  def convert_currency(from, to, amount) do
    params = [from: from, to: to, amount: amount]
    url = url() <> "/convert"
    {:ok, %{"result" => result}} = api_callback(url, params)
    result
  end

  def api_callback(url, params) do
    params = params ++ [access_key: access_key()]
    {:ok, response} = HTTPoison.get(url, [], params: params)

    case Jason.decode(response.body) do
      {:ok, %{"error" => %{"code" => code}}} -> Logger.info("response: #{inspect(code)}")
      {:ok, %{"success" => true}} = response -> response
    end
  end
end
