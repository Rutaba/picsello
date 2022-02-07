#!/usr/bin/env bash
# exit on error
set -o errexit

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Compile assets
npm install --prefix ./assets
npm run deploy --prefix ./assets
mix phx.digest

# Build the release and overwrite the existing release directory
MIX_ENV=prod mix release --overwrite

# if we are on a preview app and the database is fresh clone staging before migrating
ALREADY_MIGRATED=$(psql $DATABASE_URL -Aqtc "select count(*) from pg_catalog.pg_tables where tablename = 'schema_migrations'")

if [ $IS_PULL_REQUEST = "true" ] && [ $ALREADY_MIGRATED = "0" ]
then
  echo "cloning staging database"
  pg_dump $STAGING_DATABASE_URL | psql $DATABASE_URL
fi

# Migrate db and set up pubsub
_build/prod/rel/picsello/bin/picsello eval "Picsello.Release.prepare"
