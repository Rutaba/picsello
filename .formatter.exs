[
  import_deps: [:ecto, :phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "*.{ex,exs}",
    "priv/repo/**/*.exs",
    "{config,lib,test}/**/*.{ex,exs,heex}"
  ]
]
