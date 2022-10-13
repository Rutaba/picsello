defmodule Picsello.Repo do
  import Ecto.Query, only: [from: 2]

  use Ecto.Repo,
    otp_app: :picsello,
    adapter: Ecto.Adapters.Postgres

  use Paginator, include_total_count: true

  def last(schema) do
    from(s in schema, order_by: [desc: s.inserted_at], limit: 1)
    |> one()
  end

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

    defmacro jsonb ~> key do
      quote do
        fragment("(? -> ?)", unquote(jsonb), unquote(key))
      end
    end

    defmacro jsonb ~>> key do
      quote do
        fragment("(? ->> ?)", unquote(jsonb), unquote(key))
      end
    end

    defmacro jsonb_agg(jsonb) do
      quote do
        fragment("jsonb_agg(?)", unquote(jsonb))
      end
    end

    defmacro jsonb_path_query_args(jsonb, path_query, args) do
      quote do
        fragment(
          "jsonb_path_query(?,?,?)",
          unquote(jsonb),
          unquote(path_query),
          unquote(args)
        )
      end
    end

    defmacro jsonb_path_query(jsonb, path_query, type \\ nil) do
      type =
        case type do
          :first -> "jsonb_path_query_first"
          :array -> "jsonb_path_query_array"
          nil -> "jsonb_path_query"
        end

      frag = type <> "(?, ?)"

      quote do
        fragment(unquote(frag), unquote(jsonb), unquote(path_query))
      end
    end

    defmacro jsonb_object(array) do
      quote do
        fragment("jsonb_object(?)", unquote(array))
      end
    end
  end
end
