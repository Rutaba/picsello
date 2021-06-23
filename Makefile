#!make
include .env
.PHONY: help console outdated setup server test update-mix

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

setup: ## Setup the App.
	mix deps.get
	mix deps.unlock --unused
	mix compile
	mix ecto.setup

server: setup
server: ## Start the App server.
	rm -rf assets/node_modules/.cache
	mix phx.server

test: ## Run the test suite.
test: setup
	mix format
	MIX_ENV=test mix credo
	mix dialyzer
	mix test

test-watch: ## Run tests in watch mode
	git ls-files | entr mix test $(FILE)

update-mix: ## Update mix packages.
	mix deps.update --all
