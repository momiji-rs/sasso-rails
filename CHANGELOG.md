# Changelog

All notable changes to the **sasso-rails** gem are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

This gem versions independently of the `sasso` compiler gem; each release notes
the engine-gem version range it requires.

## [Unreleased]

## [0.1.7] - 2026-09-17

Requires the `sasso` gem **>= 0.14.0** (was `>= 0.2.7`), and **Ruby >= 3.2**.

### Removed

- **Ruby 3.1 support** (`required_ruby_version` is now `>= 3.2.0`), following the
  `sasso` engine gem, which dropped it in 0.14.0. CI had already stopped testing
  3.1 because the current Rails dep tree does not resolve there; now no dep set
  does.

### Changed

- Bumped the `sasso` engine-gem floor to **>= 0.14.0**. From that release the
  engine gem's version tracks the compiler crate it bundles, so the floor names
  the compiler too: core 0.14.0, at **dart-sass 1.104.1** parity, where 0.2.7
  carried core 0.6.3 (1.101.0).
- **Your built CSS will change, and so will its digest.** The compiler's output
  moved with the core, so a Propshaft/Sprockets fingerprint computed over a
  stylesheet's bytes changes on the next `assets:precompile` even when the
  stylesheet did not — expect one cache-busting round of new asset URLs. The CSS
  is equivalent; only its spelling changed. The engine gem's
  [CHANGELOG](https://github.com/momiji-rs/sasso-ruby/blob/main/CHANGELOG.md)
  lists every change; the ones most likely to show up in a Rails app:
  - A legacy color with a fractional channel writes its rgb triple as
    percentages, and compressed `hsl`/`hwb` route through `rgb` — so
    `darken(#336699, 10%)` compresses to `rgb(15%,30%,45%)`, not
    `hsl(210,50%,30%)`.
  - Global `whiteness()` / `blackness()` are **no longer built-ins** and now pass
    through as plain CSS (`whiteness(#f00)` instead of `0%`), matching dart-sass.
    This one is silent — no error, no warning — so grep for it.
  - Source-map `mappings` change: a declaration whose value is a bare `$name` now
    maps back to the variable's definition.
- No change to this gem's own API, generators, or rake tasks. Verified green
  against `sasso` 0.14.0 (23 runs, 70 assertions).

## [0.1.6] - 2026-06-25

Requires the `sasso` gem **>= 0.2.7** (was `>= 0.2.6`).

### Changed

- Bumped the `sasso` engine-gem floor to **>= 0.2.7**, whose library API now
  omits the trailing newline (adopting core sasso 0.6.3, byte-for-byte dart-sass
  parity). The compiler re-adds the conventional trailing newline when writing a
  build artifact, matching dart-sass's CLI for **both** styles:
  - **Expanded** builds are unchanged (`…}\n`), and source-mapped expanded
    builds keep dart's blank line before the `sourceMappingURL` footer.
  - **Compressed** builds now end with a single newline (`…}\n`) too — they
    previously had none, a one-byte deviation from dart-sass's CLI.

## [0.1.5] - 2026-06-25

Requires the `sasso` gem **>= 0.2.6** (was `>= 0.2.3`).

### Changed

- Bumped the `sasso` engine-gem floor to **>= 0.2.6**, which adopts core sasso
  0.6.2: **compressed** output now emits the shortest equivalent legacy-color
  form, matching dart-sass 1.101.0 byte-for-byte. A computed color such as
  `darken(#336699, 10%)` compiles to `hsl(210,50%,30%)` instead of the longer
  `rgb(38.25,76.5,114.75)`, and an integer-rgb-equivalent hsl literal
  (`hsl(210, 50%, 40%)`) collapses to `#369`. Expanded output is unchanged.

## [0.1.4] - 2026-06-15

Requires the `sasso` gem **>= 0.2.3** (was `>= 0.2.0`).

### Changed

- Bumped the `sasso` engine-gem floor to **>= 0.2.3**, which pulls in two
  dart-sass parity fixes contributed upstream by @shyim:
  - **`!default` no longer evaluates its right-hand side when the variable is
    already set.** This fixes a spurious "incompatible units" error seen in
    Bootstrap-on-Shopware setups.
  - **Legacy `rgb()`/`hsl()` preserve the caller's `rgba`/`hsla` spelling in
    special-value passthroughs** (e.g. `rgba(var(--bs-body-color-rgb), …)`),
    which Bootstrap relies on.

## [0.1.3] - 2026-06-14

### Fixed

- **Sprockets `assets:precompile` crash (`LoadError: cannot load such file --
  sassc`).** On a Sprockets app (e.g. a default Rails 7.0 app), the install
  generator left the manifest's default `//= link_directory ../stylesheets .css`
  directive in place, so Sprockets 4 tried to COMPILE the `application.scss`
  entrypoint with its built-in `SasscProcessor` (`require "sassc"`, not
  installed) — harmless in dev but crashing `assets:precompile` on deploy. The
  generator now neutralizes that directive (sasso owns the compiled output,
  served from `../builds`, which is linked separately). Idempotent, and a no-op
  on Propshaft (no manifest). Rails 7.0 + Sprockets now precompiles cleanly;
  Propshaft (Rails 7.1 / 8.x) is unaffected. Verified end-to-end across both
  pipelines, plus a generator unit test.

## [0.1.2] - 2026-06-14

Requires the `sasso` gem **>= 0.2.0** (for its source-map API).

### Added

- **Source maps.** `sasso:build` writes a `<output>.map` sidecar next to each
  compiled CSS and appends the `sourceMappingURL` footer. Controlled by
  `config.sasso.source_map` (default: on outside production, off in production);
  the map's `sources` are rewritten relative to the builds directory and `file`
  points at the built CSS.

Makes `bin/rails generate sasso:install` drop-in on a fresh Rails 8 app.

### Fixed

- The installer now removes the default `app/assets/stylesheets/application.css`,
  which otherwise collides with the compiled `app/assets/builds/application.css`
  on the asset load path (both resolve to the logical path `application.css`).
- The installer repoints the Rails 8 default layout's `stylesheet_link_tag :app`
  to `stylesheet_link_tag "application"` so the compiled CSS is actually linked
  (no-op if the layout already links `"application"` or was customized).

## [0.1.0] - 2026-06-13

Initial release. Requires the `sasso` gem **>= 0.1.1, < 1**.

### Added

- `Sasso::Rails::Engine` — wires sasso into a Rails app with `config.sasso.*`
  (`builds`, `style`, `load_paths`, `source_dir`, `build_dir`).
- Rake tasks `sasso:build`, `sasso:watch`, and `sasso:clobber`; `sasso:build`
  is enhanced onto `assets:precompile` (and `sasso:clobber` onto
  `assets:clobber`).
- `Sasso::Rails::Compiler` — Rails-free build object; compiles each entrypoint
  with the in-process `Sasso.compile` (no subprocess / Node.js) and writes to
  `app/assets/builds`.
- `bin/rails sasso:install` generator: scaffolds `application.scss`, the builds
  directory, a Sprockets manifest link (when present), and a `Procfile.dev`
  watch process.
- Propshaft-first, Sprockets-compatible (compiled CSS is served as a static
  build artifact by either pipeline).
