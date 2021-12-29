defmodule Picsello.Galleries.Order do
  @moduledoc false
  use Ecto.Schema
  alias Picsello.Galleries.Gallery
  
  schema "gallery_orders" do
    field :number, :integer
    field :total_credits_amount, :integer
    field :subtotal_cost, :integer
    field :shipping_cost, :integer
    field :placed, :boolean
    
    belongs_to(:gallery, Gallery)
    
    embeds_many :products, LineItem do
      field :type, :string
      field :price, :integer
      field :quantity, :integer
      field :size, :string
      field :shipping_status, :string
      field :tracking_url, :string
    end

    embeds_many :digitals, LineItem do
      field :photo_id, :integer  
      field :preview_url, :string
      field :price, :integer
    end

    ## delivery_info types -> ["digital", "physical", "all"]
    embeds_one :delivery_info, DeliveryInfo do
      field :type, :string
      field :name, :string
      field :city, :string	
      field :state, :string	
      field :zip, :integer
      field :address_line1, :string
      field :address_line2, :string
    end
    
    timestamps(type: :utc_datetime)
  end
end
