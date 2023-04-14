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
end
