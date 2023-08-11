defmodule Picsello.Utils do
  @moduledoc false
  def render(template, data),
    do: :bbmustache.render(template, data, key_type: :binary, value_serializer: &to_string/1)

  def capitalize_all_words(value) do
    value
    |> Phoenix.Naming.humanize()
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize(&1))
  end

  # it is a list because when we have shipping to canada figured out, we will add "CAD" to this list.
  def products_currency() do
    ["USD"]
  end

  # it is a list since stripe only supports certain currencies for certain payment options, etc
  def payment_options_currency(:allow_afterpay_clearpay) do
    ["USD", "CAD", "GBP", "AUD", "NZD"]
  end

  def payment_options_currency(:allow_affirm) do
    ["USD", "CAD"]
  end

  def payment_options_currency(:allow_klarna) do
    payment_options_currency()
  end

  def payment_options_currency(:allow_cashapp) do
    ["USD"]
  end

  # pattern match to get the list of all currencies enabled for the entire section
  def payment_options_currency() do
    ["USD", "CAD", "GBP", "AUD", "NZD", "CHF", "CZK", "DKK", "EUR", "NOK", "PLN", "SEK"]
  end
end
