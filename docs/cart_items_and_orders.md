# Picsello System Documentation for Digital Line Items, Product Line Items and Pricing

## Digital Line Items

The Picsello system manages digital line items using the `Picsello.Cart.Digital` module. Digital line items are used for products related to digital content.

### Schema

- `photo`: Belongs to a photo in the Picsello Galleries.
- `order`: Belongs to an order in the Picsello Cart.
- `price`: Represents the price using the `Money.Ecto.Map.Type`.
- `is_credit`: A boolean field, defaulting to `false`.
- `preview_url`: A virtual string field.
- `currency`: A virtual string field.
- `timestamps`: Includes `inserted_at` and `updated_at` of type `utc_datetime`.

### Price Calculation

- `charged_price`: Computes the price based on whether `is_credit` is `true` or `false`.

### Type Definition

```elixir
@type t :: %__MODULE__{
  photo: Ecto.Association.NotLoaded.t() | Picsello.Galleries.Photo.t(),
  order: Ecto.Association.NotLoaded.t() | Picsello.Cart.Order.t(),
  price: Money.t(),
  is_credit: boolean(),
  preview_url: nil | String.t(),
  inserted_at: DateTime.t(),
  updated_at: DateTime.t()
}
```

## Product Line Items

The Picsello system handles product line items through the `Picsello.Cart.Product` module. These line items pertain to customized WHCC products.

### Schema

- `editor_id`: A string identifier.
- `preview_url`: A string for the product's preview URL.
- `quantity`: An integer representing the quantity.
- `selections`: A map with customizable product selections.
- `shipping_base_charge`: Price for the base shipping.
- `shipping_type`: Shipping type, one of [economy, 3_days, 1_day].
- `shipping_upcharge`: Upcharge for shipping.
- `unit_markup`: Markup on the unit price.
- `total_markuped_price`: Total price after markup.
- `unit_price`: Price per unit.
- `das_carrier_cost`: Cost for DAS carrier service.
- `print_credit_discount`: Discount for print credit, default is 0.
- `volume_discount`: Volume discount.
- `price`: The product's price.
- `order`: Belongs to an order in the Picsello Cart.
- `whcc_product`: Belongs to a WHCC product.
- `timestamps`: Includes `inserted_at` and `updated_at` of type `utc_datetime`.

### Type Definition

```elixir
@type t :: %__MODULE__{
  editor_id: String.t(),
  preview_url: String.t(),
  quantity: integer(),
  selections: %{String.t() => any()},
  shipping_base_charge: Money.t(),
  shipping_upcharge: Decimal.t(),
  unit_markup: Money.t(),
  unit_price: Money.t(),
  print_credit_discount: Money.t(),
  volume_discount: Money.t(),
  price: Money.t(),
  order: Ecto.Association.NotLoaded.t() | Picsello.Cart.Order.t(),
  whcc_product: Ecto.Association.NotLoaded.t() | Picsello.Product.t(),
  inserted_at: DateTime.t(),
  updated_at: DateTime.t()
}
```

### Changeset and Pricing Calculation

- `changeset`: Defines how changesets are created for product line items.
- `charged_price`: Computes the price after considering discounts.

## Order

Orders are managed using the `Picsello.Cart.Order` module. Each order can contain digital and product line items.

### Schema

- `bundle_price`: Price of the entire order bundle.
- `number`: A unique order number.
- `placed_at`: The timestamp when the order was placed.
- `total_credits_amount`: The total amount of credits used in the order.
- `gallery_client`: Belongs to a gallery client.
- `gallery`: Belongs to a gallery.
- `album`: Belongs to an album.
- `order_currency`: References a currency code.
- `package`: Has one package associated with the order.
- `invoice`: Has one invoice related to the order.
- `intent`: Has one intent with a status other than 'canceled'.
- `canceled_intents`: Has many intents with a 'canceled' status.
- `digitals`: Has many digital line items.
- `products`: Has many product line items.
- `delivery_info`: Embedded delivery information.
- `whcc_order`: Embedded WHCC order information.
- `timestamps`: Includes `inserted_at` and `updated_at` of type `utc_datetime`.

### Type Definition

```elixir
@type t :: %__MODULE__{}
```

### Creating and Updating Changesets

- `create_changeset`: Explains how changesets are created for products, digitals, and bundles.
- `update_changeset`: Describes changesets for updating products and digitals.
- `whcc_order_changeset`: Defines changesets for WHCC orders.
- `placed_changeset`: Marks an order as placed.
- `whcc_confirmation_changeset`: Includes WHCC confirmation details.
- `store_delivery_info`: Stores delivery information in the order.

### Pricing and Order Status

- `number`: Calculates the order number based on the order's id.
- `placed`?: Checks if an order has been placed.
- `product_total`: Calculates the total cost of product line items, including shipping.
- `digital_total`: Calculates the total cost of digital line items.
- `total_cost`: Computes the total cost of the order, including both products and digitals.
- `lines_by_product`: Sorts products within the order.
- `canceled?`: Checks if an order has any canceled intents.
- Helper functions for calculating prices and managing product lists.

## Picsello.Workers.PackDigitals

This module seems to be responsible for processing background jobs related to packing digital items into a zip file. The perform/1 function performs the job, and it uploads the digital items, notifies relevant entities when the job is done or encounters errors.

### Key functions

- `perform/1`: Handles the background job and interacts with digital items.
- `enqueue/2`: Adds a job to the queue for later execution.
- `cancel/2`: Cancels jobs associated with specific parameters.
- `broadcast/3`: Sends notifications or broadcasts messages.
- `to_packable/1`: Converts a map into a packable data structure.
- `context_module/1`: Determines the context module based on the input data.
- `bundle_purchased?/1`: Delegates to a function in the Picsello.Orders module.

## Picsello.Workers.PackGallery

This module manages background jobs related to galleries and ensuring they have the latest images. It schedules jobs for packing digital items, with a focus on galleries.

### Key functions

- `perform/1`: Handles gallery-related background job execution.
- `enqueue/1`: Enqueues jobs for packing digital items.
- `can_download_all?/1`: Delegates to a function in the Picsello.Orders module.

## Picsello.Workers.PackPhotos

This module deals with background jobs for creating zip files of photos. It uploads photos and sends notifications.

### Key functions

- `perform/1`: Handles the background job for photo zip creation.
- `executing?/1`: Checks if a specific job is currently executing.

## Picsello.WHCC

This module appears to be part of the WHCC integration for image processing. It defines functions related to WHCC's products, categories, and more.

### Key functions

- Several functions for managing WHCC products and categories.
- Functions for creating editors, orders, and handling webhooks.
- Functions for pricing calculations.
- Functions for retrieving WHCC product details.

## Picsello.GalleryProducts

This module focuses on gallery products, allowing the creation and management of gallery-specific products. It can toggle product settings and retrieve products.

### Key functions

- `upsert_gallery_product/2`: Upserts gallery products with attributes.
- `get/1`: Retrieves gallery products based on specific fields.
- `toggle_sell_product_enabled/1` and `toggle_product_preview_enabled/1`: Toggles product settings.
- `editor_type/1`: Determines the editor type based on a category.
- `get_gallery_products/2`: Retrieves gallery products, potentially filtered by coming soon status.
- `remove_photo_preview/1`: Removes photo previews from gallery products.
- `get_or_create_gallery_product/2`: Retrieves or creates gallery products.
- `get_gallery_product/2`: Retrieves a gallery product.
- `get_whcc_products/1`: Retrieves WHCC products for a category.
- `get_whcc_product/1` and get_whcc_product_category/1: Retrieve WHCC product details.
- Other functions for mapping and calculating costs.

## Picsello.PricingCalculations

This module deals with pricing calculations for photographers. It contains functions for calculating income, taxes, costs, and more based on input parameters. The module also handles business costs and tax schedules.

### Key functions

- Several functions for generating changesets for input data.
- Functions for determining income tax brackets.
- Functions for calculating after-tax income, tax amounts, take-home income, and more.
- Functions for handling monthly calculations and day options.
- Functions for managing business cost categories.
- Functions for dealing with tax schedules and tax brackets.
- These modules work together to manage background jobs, image processing, pricing calculations, and interactions with external services like WHCC.

## Picsello.Cart.Checkouts Module

The Picsello.Cart.Checkouts module is responsible for handling the checkout process for a shopping cart. It contains various functions and logic related to checking out a cart, creating orders, and managing payment sessions.

### Module Purpose

- `Context`: This module serves as a context module for checking out a cart.
- `Dependencies`: It depends on several other modules and libraries within the Picsello application, including those related to cart management, orders, galleries, payments, and more.

### Module Functions

- `check_out(order_id, opts)`
  - `Purpose`: Initiates the checkout process for a given order.
  - `Parameters`:
    - `order_id (integer)`: The ID of the order to be checked out.
    - `opts (map)`: Additional options and parameters for the checkout.
  - `Returns`:
    - `{:ok, map()}`: If the checkout process is successful.
    - `{:error, any(), any(), map()}`: If an error occurs during the checkout.

- `handle_previous_session(order_id)`
  - `Purpose`: Handles the previous checkout session for an order.
  - `Parameters`:
    - `order_id (integer)`: The ID of the order.
  - `Returns`: A modified multi-operation object.

- `load_previous_intent(order_id)`
  - `Purpose`: Loads the previous intent associated with an order.
  - `Parameters`:
    - `order_id (integer)`: The ID of the order.
  - `Returns`: The previous intent or nil if none is found.

- `expire_previous_session(repo, intent)`
  - `Purpose`: Expires the previous checkout session.
  - `Parameters`:
    - `repo`: The Ecto repository.
    - `intent`: The previous intent to expire.
  - `Returns`: An updated session with the intent canceled.

- `update_previous_intent(intent)`
  - `Purpose`: Updates the previous intent after it has been expired.
  - `Parameters`:
    - `intent`: The previous intent.
  - `Returns`: The updated intent.

- `load_cart(repo, multi, order_id)`
  - `Purpose`: Loads the shopping cart for a given order.
  - `Parameters`:
    - `repo`: The Ecto repository.
    - `multi`: The multi-operation object.
    - `order_id (integer)`: The ID of the order.
  - `Returns`:
    - `{:ok, order}`: If the cart is successfully loaded.
    - `{:error, :not_found}`: If the cart is not found.

- `create_whcc_order(order)`
  - `Purpose`: Creates a WHCC (White House Custom Colour) order based on the contents of the shopping cart.
  - `Parameters`:
    - `order`: The order for which to create a WHCC order.
  - `Returns`: A modified multi-operation object.
  
- `editors({whcc_product, line_items}, acc, shipment_details)`
  - `Purpose`: Collects editors and order attributes for WHCC products.
  - `Parameters`:
    - `whcc_product`: The WHCC product.
    - `line_items`: Line items associated with the product.
    - `acc`: Accumulator for editors.
    - `shipment_details`: Details of the shipment.
  - `Returns`: A list of editors.

- `create_session(order, opts)`
  - `Purpose`: Creates a payment session for checkout.
  - `Parameters`:
    - `order`: The order for which to create a session.
    - `opts`: Additional options.
  - `Returns`: A modified multi-operation object.

- `shipping_options(order)`
  - `Purpose`: Determines the available shipping options based on the order's contents.
  - `Parameters`:
    - `order`: The order for which to calculate shipping options.
  - `Returns`: A list of shipping options.

- `place_order(cart)`
  - `Purpose`: Places an order and updates it as "placed."
  - `Parameters`:
    - `cart`: The shopping cart.
  - `Returns`: A changeset representing the placed order.

- `client_total(repo, cart)`
  - `Purpose`: Calculates the total cost for the client.
  - `Parameters`:
    - `repo`: The Ecto repository.
    - `cart`: The shopping cart.
  - `Returns`: The total cost.

- `fetch_previous_stripe_intent(repo, intent)`
  - `Purpose`: Fetches the previous Stripe intent for a given order.
  - `Parameters`:
    - `repo`: The Ecto repository.
    - `intent`: The intent to fetch the previous Stripe intent.
  - `Returns`: The previous Stripe intent.

- `build_line_items(order)`
  - `Purpose`: Builds line items for the order to be used in the payment session.
  - `Parameters`:
    - `order`: The order.
  - `Returns`: A list of line items.

- `to_line_item(digital)`
  - `Purpose`: Converts a digital product to a line item.
  - `Parameters`:
    - `digital`: The digital product.
  - `Returns`: A line item for the digital product.

- `to_line_item(product)`
  - `Purpose`: Converts a physical product to a line item.
  - `Parameters`:
    - `product`: The physical product.
    - `Returns`: A line item for the physical product.

- `to_line_item(order)`
  - `Purpose`: Converts a bundle order to a line item.
  - `Parameters`:
    - `order`: The bundle order.
  - `Returns`: A line item for the bundle order.

- `run(multi, name, fun, args)`
  - `Purpose`: Runs a function as part of a multi-operation.
  - `Parameters`:
    - `multi`: The multi-operation object.
    - `name`: The name of the operation.
    - `fun`: The function to run.
    - `args`: Arguments for the function.

## Picsello.Cart.DeliveryInfo Module

The Picsello.Cart.DeliveryInfo module defines a schema for holding delivery information related to an order.

### Module Purpose

- `Structure/Schema`: This module defines the structure and schema for order delivery information.
- `Validation`: It includes validation and changeset functions for ensuring the correctness of delivery information.
- `Address Embedding`: The schema allows for the embedding of address details within the delivery information.

### Module Functions

- `changeset(delivery_info, attrs, opts)`
  - `Purpose`: Creates a changeset for the delivery information, considering order-specific attributes.
  - `Parameters`:
    - `delivery_info (struct)`: The existing delivery information.
    - `attrs (map)`: Attributes to apply to the changeset.
    - `opts (map)`: Additional options for changeset creation.
  - `Returns`: A changeset for delivery information, taking into account order-specific attributes.

- `changeset(nil, attrs)`
  - `Purpose`: Creates a changeset for delivery information when none exists (for new entries).
  - `Parameters`:
    - `attrs (map)`: Attributes to apply to the changeset.
  - `Returns`: A changeset for new delivery information.

- `changeset(delivery_info, attrs)`
  - `Purpose`: Creates a changeset for the delivery information.
  - `Parameters`:
    - `delivery_info (struct)`: The existing delivery information.
    - `attrs (map)`: Attributes to apply to the changeset.
  - `Returns`: A changeset for the delivery information.

- `changeset_for_zipcode(struct, attrs)`
  - `Purpose`: Creates a changeset specifically for handling ZIP code attributes in the address.
  - `Parameters`:
    - `struct (struct)`: The existing delivery information.
    - `attrs (map)`: Attributes to apply to the changeset.
  - `Returns`: A changeset for the delivery information with a focus on ZIP code attributes.

- `selected_state(changeset)`
  - `Purpose`: Retrieves the selected state from a delivery information changeset.
  - `Parameters`:
    - `changeset (changeset)`: The changeset containing delivery information.
  - `Returns`: The selected state from the changeset.

- `states()`
  - `Purpose`: Provides a list of U.S. state abbreviations.
  - `Returns`: A list of U.S. state abbreviations.

### Address Submodule

The Picsello.Cart.DeliveryInfo module also includes a submodule called Address, which defines the structure and schema for address details embedded within delivery information.

### Submodule Functions

- `changeset(address, attrs)`
  - `Purpose`: Creates a changeset for address details.
  - `Parameters`:
    - `address (struct)`: The existing address details.
    - `attrs (map)`: Attributes to apply to the changeset.
  - `Returns`: A changeset for address details.

- `changeset_for_zipcode(struct, attrs)`
  - `Purpose`: Creates a changeset specifically for handling ZIP code attributes in address details.
  - `Parameters`:
    - `struct (struct)`: The existing address details.
    - `attrs (map)`: Attributes to apply to the changeset.
  - `Returns`: A changeset for address details with a focus on ZIP code attributes.

- `states()`
  - `Purpose`: Provides a list of U.S. state abbreviations.
  - `Returns`: A list of U.S. state abbreviations.

This documentation provides an overview of the Picsello system, covering `digital` and `product line items` and the order management process. It also explains how pricing is calculated and includes relevant `data types` and `functions`. It also defines several modules that are part of the `Picsello application`, likely related to image and `gallery management`, `pricing calculations`, and `integration` with a service provider `(e.g., WHCC)`. Also includes the fundamental part of `managing order delivery information` within the Picsello application, ensuring that `delivery details` are correctly structured and validated before being associated with an order.
