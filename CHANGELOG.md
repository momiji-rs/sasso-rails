# Changelog

All notable changes to the **sasso-rails** gem are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

This gem versions independently of the `sasso` compiler gem; each release notes
the engine-gem version range it requires.

## [Unreleased]

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
