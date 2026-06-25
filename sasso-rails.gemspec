# frozen_string_literal: true

require_relative "lib/sasso/rails/version"

Gem::Specification.new do |spec|
  spec.name     = "sasso-rails"
  spec.version  = Sasso::Rails::VERSION
  spec.authors  = ["momiji-rs"]
  spec.summary  = "Rails integration for the sasso SCSS/Sass compiler"
  spec.description = "Compiles Sass/SCSS to CSS in the Rails asset pipeline " \
                     "(Propshaft-first, Sprockets-compatible) using the in-process " \
                     "sasso native extension — no Node.js, no subprocess."
  spec.homepage = "https://github.com/momiji-rs/sasso-rails"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*",
    "README.md",
    "CHANGELOG.md",
    "LICENSE-MIT",
  ]
  spec.require_paths = ["lib"]

  # Pure-Ruby integration: NO native extension here (the compiler lives in the
  # `sasso` gem). Hence no `spec.extensions`.
  spec.add_dependency "railties", ">= 7.0.0"
  # The compiler engine gem. `>= 0.2.6` requires the source-map API
  # (`compile(source_map: true)`, since 0.2.0) plus the dart-sass parity fixes
  # through 0.2.6: `!default` no longer evaluates an already-set RHS and legacy
  # `rgb()`/`hsl()` preserve the caller's `rgba`/`hsla` spelling (0.2.3); and
  # compressed output emits the shortest equivalent legacy-color form, e.g.
  # `darken(#336699, 10%)` -> `hsl(210,50%,30%)` (0.2.6). `< 1` allows the rest
  # of the 0.x line (the tiny Ruby API surface is stable).
  spec.add_dependency "sasso", ">= 0.2.6", "< 1"
end
