# Picsello

## Development

Copy `.env.example` to `.env` and fill in the values. Some can be found on the [staging render dashboard](https://dashboard.render.com/web/srv-c2rpv4girho5clngbd4g/shell).

### Setup Image Processing 

1. When you create your `.env`, be sure to add `PHOTO_PROCESSING_OUTPUT_TOPIC` and `GOOGLE_APPLICATION_CREDENTIALS`, so images created on your environment will get to you from [Cloud Function](https://console.cloud.google.com/cloudpubsub/topic/list?project=celtic-rite-323300).

To start the dev server:

    make server

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Deploy to staging

Push to master to deploy to [staging](https://picsello-staging.onrender.com/). If [CI](https://github.com/Picsello/picsello-app/actions/workflows/ci.yml) passes it will automatically deploy.

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix


