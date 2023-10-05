defmodule Picsello.Utils do
  @moduledoc false

  alias Ecto.Changeset

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

  @doc """
  Expects a date_time in string format such as '2023-10-08T00:00:00' and returns
  it in unix with given offset. Default offset is 60 seconds or 00:01.
  Example
  > to_unix("2023-10-08T00:00:00")
  {:ok, ~U[2023-10-08 00:01:00Z], -60}
  """
  def to_unix(datetime, offset \\ "00:01") do
    {:ok, datetime, _} = DateTime.from_iso8601(datetime <> "-" <> offset)
    DateTime.to_unix(datetime)
  end

  @doc """
  Normalizes an HTML body template by replacing predefined escape sequences with their respective characters.

  This function takes an HTML body template as input and replaces predefined escape sequences with their corresponding characters. The replacement rules are specified in the `@replacements` module attribute, which is a list of tuples where the first element is the escape sequence to be replaced, and the second element is the character it should be replaced with.

  ## Examples

      ```elixir
      body = "<p>This is an &lt;example&gt;.</p>"
      normalize_body_template(body)
      # Output: "<p>This is an <example>.</p>"
      ```

  ## Parameters

      - `body` (string): The HTML body template to be normalized.

  ## Returns

  A string representing the HTML body template with escape sequences replaced by their corresponding characters.
  """

  @replacements [
    {"&lt;", "<"},
    {"&gt;", ">"},
    {"/a&gt;", "/a>"},
    {"&quot;", "\""},
    {"&apos;", "\'"}
  ]

  @spec normalize_body_template(body :: String.t()) :: String.t()
  def normalize_body_template(body) do
    @replacements
    |> Enum.reduce(body, fn {from, to}, acc ->
      String.replace(acc, from, to)
    end

  @doc """
  Validate phone value according to its country
  """
  def validate_phone(%Changeset{} = changeset, field) when is_atom(field) do
    unless is_map_key(changeset.data, field) do
      raise "Got unknown field #{field} while validating phone number"
    end

    changeset
    |> Changeset.get_change(field)
    |> then(fn
      phone when is_nil(phone) ->
        changeset

      phone ->
        if LivePhone.Util.valid?(phone) do
          changeset
        else
          Changeset.add_error(changeset, field, "is invalid")
        end
    end)
  end
end
