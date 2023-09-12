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
  # here, planning ahead once we figure out how to support other countries stripe supports
  def payment_options_currency(:allow_afterpay_clearpay), do: payment_options_currency()

  def payment_options_currency(:allow_affirm), do: payment_options_currency()

  def payment_options_currency(:allow_klarna), do: payment_options_currency()

  def payment_options_currency(:allow_cashapp), do: payment_options_currency()

  # pattern match to get the list of all currencies enabled for the entire section
  def payment_options_currency() do
    ["USD"]
  end
end
