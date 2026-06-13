# Changelog

All notable changes to the **sasso-rails** gem are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

This gem versions independently of the `sasso` compiler gem; each release notes
the engine-gem version range it requires.

## [Unreleased]

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
