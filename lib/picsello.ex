defmodule Picsello do
  @moduledoc """
  Picsello keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
end

defimpl Jason.Encoder, for: Money do
  def encode(value, opts), do: value |> to_string() |> Jason.Encode.string(opts)
end

defimpl String.Chars, for: Money do
  def to_string(value) do
    if Money.negative?(value) do
      "-" <> (value |> Money.neg() |> Money.to_string())
    else
      Money.to_string(value)
    end
  end
end
