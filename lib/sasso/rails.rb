# frozen_string_literal: true

require "sasso"                 # the compiler engine gem (native extension)
require "sasso/rails/version"
require "sasso/rails/compiler"

# Rails integration for the `sasso` SCSS/Sass compiler.
#
# Propshaft-first build-task model (mirrors rails/dartsass-rails): compile the
# configured entrypoints to plain CSS in `app/assets/builds/`, where the asset
# pipeline (Propshaft on Rails 8, or Sprockets serving it as a static file)
# fingerprints and serves them. Unlike dartsass-rails/tailwindcss-rails — which
# shell out to a standalone binary — this calls `Sasso.compile` IN-PROCESS via
# the native extension, so there is no subprocess, IPC, or binary-path lookup.
module Sasso
  module Rails
    # Loaded only inside a Rails process; the Compiler is usable standalone.
    require "sasso/rails/engine" if defined?(::Rails::Railtie)
  end
end
