defmodule Picsello.WHCC.WebhooksTest do
  use ExUnit.Case, async: true
  alias Picsello.WHCC.Webhooks

  describe "parse_payload" do
    test "parses accepted status" do
      assert {:ok,
              %Webhooks.Status{
                status: "Accepted",
                errors: [],
                order_number: 14_989_342,
                event: "Processed",
                confirmation_id: "a3ff9b4a-3112-4101-88ab-6ba025fd7600",
                entry_id: "12345",
                reference: "OrderID 12345",
                sequence_number: 1
              }} =
               Webhooks.parse_payload(%{
                 "Status" => "Accepted",
                 "Errors" => [],
                 "OrderNumber" => 14_989_342,
                 "Event" => "Processed",
                 "ConfirmationId" => "a3ff9b4a-3112-4101-88ab-6ba025fd7600",
                 "EntryId" => "12345",
                 "Reference" => "OrderID 12345",
                 "SequenceNumber" => "1"
               })
    end

    test "parses rejected status" do
      assert {:ok,
              %Webhooks.Status{
                status: "Rejected",
                errors: [
                  %Webhooks.Error{
                    error_code: "400.03",
                    error: "Error copying files from consumer.",
                    info: %{
                      "asset_path" =>
                        "https://whcc-api-testing.s3.amazonaws.com/sample-images/not-valid-image-1.jpg"
                    }
                  }
                ],
                order_number: nil,
                event: "Processed",
                confirmation_id: "a3ff9b4a-3112-4101-88ab-6ba025fd7600",
                entry_id: "12345",
                reference: "OrderID 12345",
                sequence_number: 1
              }} =
               Webhooks.parse_payload(%{
                 "Status" => "Rejected",
                 "Errors" => [
                   %{
                     "ErrorCode" => "400.03",
                     "Error" => "Error copying files from consumer.",
                     "AssetPath" =>
                       "https://whcc-api-testing.s3.amazonaws.com/sample-images/not-valid-image-1.jpg"
                   }
                 ],
                 "Event" => "Processed",
                 "ConfirmationId" => "a3ff9b4a-3112-4101-88ab-6ba025fd7600",
                 "EntryId" => "12345",
                 "Reference" => "OrderID 12345",
                 "SequenceNumber" => "1"
               })
    end

    test "parses shipped event" do
      assert {:ok,
              %Webhooks.Event{
                order_number: 14_989_342,
                event: "Shipped",
                confirmation_id: "a3ff9b4a-3112-4101-88ab-6ba025fd7600",
                entry_id: "12345",
                reference: "OrderID 12345",
                sequence_number: 1,
                shipping_info: [
                  %Webhooks.ShippingInfo{
                    carrier: "FedEx",
                    ship_date: ~U[2018-12-31 12:18:38Z],
                    tracking_number: "512376671311227",
                    tracking_url: "http://www.fedex.com/Tracking?tracknumbers=512376671311227",
                    weight: 0.35
                  }
                ]
              }} =
               Webhooks.parse_payload(%{
                 "ShippingInfo" => [
                   %{
                     "Carrier" => "FedEx",
                     "ShipDate" => "2018-12-31T06:18:38-06:00",
                     "TrackingNumber" => "512376671311227",
                     "TrackingUrl" =>
                       "http://www.fedex.com/Tracking?tracknumbers=512376671311227",
                     "Weight" => 0.35
                   }
                 ],
                 "OrderNumber" => 14_989_342,
                 "Event" => "Shipped",
                 "ConfirmationId" => "a3ff9b4a-3112-4101-88ab-6ba025fd7600",
                 "EntryId" => "12345",
                 "Reference" => "OrderID 12345",
                 "SequenceNumber" => "1"
               })
    end
  end
end
