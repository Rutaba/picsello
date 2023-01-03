#!make
include .env
.PHONY: help console outdated setup server test test-clear update-mix check iex

HELP_PADDING = 20

help: ## Shows this help.
	@IFS=$$'\n' ; \
	help_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//'`); \
	for help_line in $${help_lines[@]}; do \
			IFS=$$'#' ; \
			help_split=($$help_line) ; \
			help_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
			help_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
			printf "%-$(HELP_PADDING)s %s\n" $$help_command $$help_info ; \
	done

.env:
	cp .env.example .env

console: ## Opens the App console.
	iex -S mix

outdated: ## Shows outdated packages.
	mix hex.outdated

assets/node_modules: assets/package.json assets/package-lock.json
	npm install --prefix=assets
	touch $@

deps: mix.exs mix.lock
	mix deps.get
	touch $@

setup: assets/node_modules
setup: deps
setup: ## Setup the App.
	mix deps.unlock --unused
	mix compile
	mix ecto.setup

server: setup
server: ## Start the App server.
	rm -rf assets/node_modules/.cache
	mix phx.server

test: ## Run the test suite.
test: setup check test-clear
	rm -f screenshots/*.png
	mix test $(MIX_TEXT_ARGS)

test-clear:
	ps ax | grep '[Cc]hrome.*--headless' | cut -f1 -d ' ' | xargs kill -9 | true
	killall -vz chromedriver | true

test-watch: ## Run tests in watch mode
	git ls-files | entr mix test $(FILE)

update-mix: ## Update mix packages.
	mix deps.update --all

stripe-connect-listen:
	stripe listen --log-level=debug --forward-to=localhost:4000/stripe/connect-webhooks --latest --events=payment_intent.canceled,checkout.session.completed --api-key=${STRIPE_SECRET}

stripe-app-listen:
	stripe listen --log-level=debug --forward-to=localhost:4000/stripe/app-webhooks --latest --events=customer.subscription.created,customer.subscription.updated,customer.subscription.deleted,customer.subscription.trial_will_end,invoice.payment_succeeded,invoice.payment_failed --api-key=${STRIPE_SECRET}

rollback:
	mix ecto.rollback && MIX_ENV=test mix ecto.rollback

migrate:
	mix ecto.migrate && MIX_ENV=test mix ecto.migrate

check:
	mix format
	MIX_ENV=test mix credo
	mix dialyzer

iex: setup
	iex -S mix phx.server
