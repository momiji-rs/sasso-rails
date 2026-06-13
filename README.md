# sasso-rails

Rails integration for [**sasso**](https://github.com/momiji-rs/sasso-ruby) — a
pure-Rust, zero-dependency SCSS/Sass → CSS compiler (a byte-for-byte dart-sass
alternative).

Compiles your stylesheets into `app/assets/builds/` for the Rails asset
pipeline to serve. **Propshaft-first** (the Rails 8 default) and
Sprockets-compatible.

Why this gem over the alternatives:

- **No Node.js.** Unlike `cssbundling-rails`, there is no `node`/`yarn`/`npx`
  requirement — the compiler ships as a precompiled Ruby native gem.
- **In-process, no subprocess.** Unlike `dartsass-rails` / `tailwindcss-rails`
  (which shell out to a standalone binary), sasso-rails calls `Sasso.compile`
  directly through the native extension — no process spawn, no IPC.
- **Pure Rust core.** No libsass (deprecated), no Dart VM.

## Installation

```ruby
# Gemfile
gem "sasso-rails"
```

```sh
bundle install
bin/rails generate sasso:install
```

The installer scaffolds `app/assets/stylesheets/application.scss`, creates
`app/assets/builds/` (with a `.keep`), removes the default
`app/assets/stylesheets/application.css` (it would collide with the compiled
output), links the builds directory in a Sprockets manifest if one exists, adds
a watch process to `Procfile.dev`, and points your layout at the compiled CSS:

```erb
<%= stylesheet_link_tag "application" %>
```

(On Rails 8 the default layout links `:app`; the installer repoints it to
`"application"`. If you wire the link yourself, use `"application"`.)

## Usage

```sh
bin/rails sasso:build     # compile once
bin/rails sasso:watch     # recompile on change (or run ./bin/dev)
bin/rails sasso:clobber   # remove generated CSS
```

`sasso:build` runs automatically before `assets:precompile`, so deploys
(`rails assets:precompile`) regenerate the CSS before the pipeline fingerprints
it. No extra deploy wiring needed.

## Configuration

In `config/application.rb` (or an environment file):

```ruby
# Map each entrypoint (under source_dir) to an output file (under build_dir).
config.sasso.builds = {
  "application.scss" => "application.css",
  "admin.scss"       => "admin.css",
}

# :expanded | :compressed. Default: :compressed in production, :expanded else.
config.sasso.style = :compressed

# Extra @use/@import include dirs. The entrypoint's own directory is always
# searched first, so sibling partials need no configuration.
config.sasso.load_paths = [Rails.root.join("vendor/styles").to_s]

# Defaults shown:
config.sasso.source_dir = "app/assets/stylesheets"
config.sasso.build_dir  = "app/assets/builds"
```

## How it fits the pipeline

`sasso:build` writes plain CSS to `app/assets/builds/`. Both pipelines treat
that directory as a source of ready-to-serve assets:

- **Propshaft** (Rails 8 default) discovers `app/assets/builds` on its load
  path, fingerprints the CSS, and rewrites `url(...)` references — it performs
  no Sass compilation itself.
- **Sprockets** serves the built CSS as a static asset (the installer adds
  `//= link_tree ../builds` to `app/assets/config/manifest.js`).

## Notes & limitations

- **Source maps are not supported yet.** The in-process compiler returns CSS
  only; there is no `.css.map` output in any environment.
- **`builds` is file-to-file.** Each entry maps one input file to one output
  file. There is no directory-glob form (no `"." => "."`); list each entrypoint
  explicitly.
- **Load paths are explicit.** Only the entrypoint's own directory (searched
  automatically) and `config.sasso.load_paths` are on the `@use`/`@import`
  search path. Gem-vendored or `config.assets.paths` stylesheets are NOT added
  automatically — list their directories in `config.sasso.load_paths`.
- **No double-minification.** On a Sprockets app that sets
  `config.assets.css_compressor`, sasso-rails stays `:expanded` and lets the
  pipeline compress (unless you pin `config.sasso.style`). Propshaft does not
  compress, so production output is `:compressed` there.
- **Watch is a 1s mtime poll** (dependency-free, no native fs-events); it covers
  the source dir and `config.sasso.load_paths`.

## Versioning

This gem versions independently of the `sasso` compiler gem and pins it with a
range (`sasso >= 0.1.1, < 1`). An app may pin a specific compiler version in its
own `Gemfile`.

## License

MIT, matching the Sass ecosystem. (The core `sasso` compiler crate remains
dual-licensed MIT OR Apache-2.0.)
