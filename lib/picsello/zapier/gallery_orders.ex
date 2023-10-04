defmodule Picsello.Zapier.GalleryOrders do
  @moduledoc """
   module for communicating with zapier to handle gallery order
   events to send to many different platforms
  """

  defmodule JsonEncoder do
    def encode(map) do
      map |> Map.from_struct() |> Jason.encode!()
    end
  end

  defimpl Jason.Encoder, for: Picsello.WHCC.Webhooks.Status do
    def encode(status, _opts), do: JsonEncoder.encode(status)
  end

  defimpl Jason.Encoder, for: Picsello.WHCC.Webhooks.Event do
    def encode(event, _opts), do: JsonEncoder.encode(event)
  end

  defimpl Jason.Encoder, for: Picsello.WHCC.Webhooks.ShippingInfo do
    def encode(shipping_info, _opts), do: JsonEncoder.encode(shipping_info)
  end

  use Tesla
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.BaseUrl, "https://hooks.zapier.com/hooks/catch")

  @doc "send WHCC updates to zapier"
  def gallery_order_whcc_update(body) do
    if config()[:gallery_order_webhook_url] do
      post(config()[:gallery_order_webhook_url], body)
    end
  end

  defp config, do: Application.get_env(:picsello, :zapier)
end
