defmodule Picsello.WHCC.Webhooks do
  @moduledoc """
    context module for handling WHCC webhooks
  """

  defmodule Error do
    @moduledoc """
      whcc error webhook payload
    """
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :error_code, :string
      field :error, :string
      field :info, :map
    end

    def changeset(error, params) do
      cast(error, Map.put(params, "info", Map.drop(params, ["error_code", "error"])), [
        :error_code,
        :error,
        :info
      ])
    end
  end

  defmodule Status do
    @moduledoc """
      whcc event webhook payload
    """
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :confirmation_id, :string
      field :entry_id, :string
      field :event, :string
      field :order_number, :integer
      field :reference, :string
      field :sequence_number, :integer
      field :status, :string
      embeds_many :errors, Error
    end

    def new(payload) do
      %__MODULE__{}
      |> cast(
        payload,
        ~w[status order_number event confirmation_id entry_id reference sequence_number]a
      )
      |> cast_embed(:errors)
      |> apply_action(:create)
    end
  end

  defmodule ShippingInfo do
    @moduledoc """
      whcc shipping info webhook payload
    """
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :carrier, :string
      field :ship_date, :utc_datetime
      field :tracking_number, :string
      field :tracking_url, :string
      field :weight, :float
    end

    def changeset(error, params) do
      cast(error, params, ~w[carrier ship_date tracking_number tracking_url weight]a)
    end
  end

  defmodule Event do
    @moduledoc """
      whcc event webhook payload
    """
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :confirmation_id, :string
      field :entry_id, :string
      field :event, :string
      field :order_number, :integer
      field :reference, :string
      field :sequence_number, :integer

      embeds_many :shipping_info, ShippingInfo
    end

    def new(payload) do
      %__MODULE__{}
      |> cast(
        payload,
        ~w[order_number event confirmation_id entry_id reference sequence_number]a
      )
      |> cast_embed(:shipping_info)
      |> apply_action(:create)
    end
  end

  def parse_payload(%{"Status" => _status} = params) do
    params |> underscore_keys() |> Status.new()
  end

  def parse_payload(%{"Event" => _event} = params) do
    params |> underscore_keys() |> Event.new()
  end

  defp underscore_keys(%{} = map) do
    for {key, value} <- map, into: %{} do
      value =
        case value do
          %{} -> underscore_keys(value)
          [%{} | _] -> Enum.map(value, &underscore_keys/1)
          _ -> value
        end

      {Phoenix.Naming.underscore(key), value}
    end
  end
end
