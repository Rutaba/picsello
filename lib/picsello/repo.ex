defmodule Picsello.Repo do
  use Ecto.Repo,
    otp_app: :picsello,
    adapter: Ecto.Adapters.Postgres

  use Paginator, include_total_count: true

  defmodule CustomMacros do
    defmacro array_to_string(array, delimiter) do
      quote do
        fragment("array_to_string(?, ?)", unquote(array), unquote(delimiter))
      end
    end

    defmacro now() do
      quote do
        fragment("now() at time zone 'utc'")
      end
    end

    defmacro nearest(number, nearest) do
      quote do
        fragment(
          "(round(?::decimal / ?::decimal) * ?::decimal)",
          unquote(number),
          unquote(nearest),
          unquote(nearest)
        )
      end
    end

    defmacro cast_money(number) do
      quote do
        type(unquote(number), Money.Ecto.Amount.Type)
      end
    end

    defmacro initcap(string) do
      quote do
        fragment("initcap(?)", unquote(string))
      end
    end
  end
end
