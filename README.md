# Picsello

## Development

Copy `.env.example` to `.env` and fill in the values. Some can be found on the [staging render dashboard](https://dashboard.render.com/web/srv-c2rpv4girho5clngbd4g/shell).

### Setup Image Processing 

When you create your `.env`, be sure to add `PHOTO_PROCESSING_OUTPUT_TOPIC`, `PHOTO_PROCESSING_OUTPUT_SUBSCRIPTION` and `GOOGLE_APPLICATION_CREDENTIALS`, so images created on your environment will get back to you from [Cloud Function](https://console.cloud.google.com/functions/list?project=celtic-rite-323300). This requires you to create your personal output topic and subscription.
1. Go to [Cloud PubSub](https://console.cloud.google.com/cloudpubsub/topic/list?project=celtic-rite-323300).
2. Click "Create Topic".
3. Fill the Topic ID with "`your_last_name`-processed-photos".
4. Ensure "Add a default subscription" checkbox checked.
5. Click "Create Topic" and wait till it finihsed.
6. This will redirect you to your topic page. It has full topic subscription name at bottom, use it as `PHOTO_PROCESSING_OUTPUT_SUBSCRIPTION` env variable.
7. Fill `PHOTO_PROCESSING_OUTPUT_TOPIC` env variable with Topic ID "`your_last_name`-processed-photos".

## To start the dev server:

    make server

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Things to sync in the console:

#### WHCC Products
1. Have the following `ENV` vars setup `WHCC_KEY`, `WHCC_SECRET`, and `WHCC_URL`
2. Run `make console`
3. Run `Picsello.WHCC.sync()`
4. Run `Picsello.CategoryTemplate.seed_templates()` (for product previews)

#### Packages and pricing tiers
1. Have the following `ENV` vars setup `PACKAGES_CALCULATOR_COST_OF_LIVING_RANGE`, `PACKAGES_CALCULATOR_PRICES_RANGE` and `PACKAGES_CALCULATOR_SHEET_ID`
2. Run `make console`
3. Run `Picsello.Workers.SyncTiers.perform(nil)`

#### Subscriptions from Stripe
(this can also be done from the admin panel at `/admin/workers`)
1. Have the following `ENV` vars setup `STRIPE_SECRET`
2. Run `make console`
3. Run `Picsello.Subscriptions.sync_subscription_plans()`

## Sendgrid inbound parse for development

1. Start ngrok: `ngrok http 4000`
1. Go to [Sendgrid Settings](https://app.sendgrid.com/settings/parse)
1. Remove the entry `dev-inbox.picsello.com` if present
1. Click Add Host & URL and set subdomain as `dev-inbox`, select `picsello.com` and on Destination url use the ngrok url followed by the path: `http://___.ngrok.io/sendgrid/inbound-parse`
1. You might want to update the Mailer settings on `config/dev.exs` if you want to also send outbound emails to sendgrid.

## Deploy to staging

Push to master to deploy to [staging](https://picsello-staging.onrender.com/). If [CI](https://github.com/Picsello/picsello-app/actions/workflows/ci.yml) passes it will automatically deploy.

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix


