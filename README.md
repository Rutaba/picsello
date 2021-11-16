# Picsello

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `npm install` inside the `assets` directory
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix


## Setup Image Processing 

1. Create PubSub Topic and Subscription. Set PHOTO_PROCESSING_OUTPUT_TOPIC and GOOGLE_APPLICATION_CREDENTIALS, so images created on your environment will get to you from Cloud Function. https://console.cloud.google.com/cloudpubsub/topic/list?project=celtic-rite-323300 

2. Set Google Credentials json location with GOOGLE_APPLICATION_CREDENTIALS
