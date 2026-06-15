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

## Compatibility

- **Ruby** ≥ 3.1.
- **Rails** ≥ 7.0 (`railties >= 7.0`), on **either** asset pipeline. Verified
  end-to-end (`generate sasso:install` → `sasso:build` → production
  `assets:precompile` → served CSS) on:

  | Rails  | Asset pipeline                                       | Status              |
  |--------|------------------------------------------------------|---------------------|
  | 8.x    | Propshaft (the Rails 8 default)                      | ✅ primary path     |
  | 7.1+   | Propshaft (`rails new --asset-pipeline=propshaft`)   | ✅                  |
  | 7.0    | Sprockets (the Rails 7.0 default)                    | ✅ (since **0.1.3**) |

  On **Propshaft** sasso compiles to `app/assets/builds/` and Propshaft serves
  it (Propshaft performs no Sass step of its own). On **Sprockets** the installer
  links that builds directory into the manifest **and** disables Sprockets' own
  `.scss` handling, so `assets:precompile` deploys cleanly without `sassc`/
  libsass (this last part is the 0.1.3 fix — earlier versions crashed
  `assets:precompile` on a default Sprockets app; see the changelog). Either way
  the compiler is the pure-Rust `sasso` native gem — no Node, no Dart, no
  subprocess.

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

# Source maps: write a <output>.map sidecar + sourceMappingURL footer.
# Default: on outside production, off in production. Set true/false to force.
config.sasso.source_map = nil

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

## Troubleshooting

**`Bundler::GemNotFound: Could not find sasso-<version>-<platform>`** on
`bin/rails sasso:build` (or any boot) right after `bundle install`. The `sasso`
compiler ships as a **precompiled native gem**, so the lockfile must list your
platform. If Bundler resolved the version but didn't materialize the native
build for your arch, add the platform and re-install:

```console
$ bundle lock --add-platform arm64-darwin   # or x86_64-linux, aarch64-linux, etc.
$ bundle install
```

This is a generic Bundler behaviour for precompiled native gems (the same step
`nokogiri` etc. need on CI/Docker), not specific to sasso — but you may hit it
on a first local install. To bake every supported platform into the lockfile up
front:

```console
$ bundle lock --add-platform x86_64-linux aarch64-linux \
    x86_64-linux-musl aarch64-linux-musl arm64-darwin x86_64-darwin x64-mingw-ucrt
```

## Versioning

This gem versions independently of the `sasso` compiler gem and pins it with a
range (`sasso >= 0.2.3, < 1`). An app may pin a specific compiler version in its
own `Gemfile`.

## License

MIT, matching the Sass ecosystem. (The core `sasso` compiler crate remains
dual-licensed MIT OR Apache-2.0.)
