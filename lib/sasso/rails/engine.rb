# frozen_string_literal: true

require "rails"
require "active_support/ordered_options"

module Sasso
  module Rails
    # Wires sasso into a Rails app. Configurable via `config.sasso.*`:
    #
    #   config.sasso.builds     # { "application.scss" => "application.css" }
    #   config.sasso.style      # :expanded | :compressed (default: env-based)
    #   config.sasso.load_paths # extra @use/@import include dirs (Array)
    #   config.sasso.source_dir # default "app/assets/stylesheets"
    #   config.sasso.build_dir  # default "app/assets/builds"
    #   config.sasso.source_map # true | false (default: on outside production)
    #
    # The `sasso:build` rake task is enhanced onto `assets:precompile`, so the
    # CSS is generated before Propshaft/Sprockets fingerprints it on deploy.
    class Engine < ::Rails::Engine
      config.sasso = ::ActiveSupport::OrderedOptions.new
      config.sasso.builds     = { "application.scss" => "application.css" }
      config.sasso.style      = nil   # resolved in `Sasso::Rails.style_for`
      config.sasso.load_paths = []
      config.sasso.source_dir = "app/assets/stylesheets"
      config.sasso.build_dir  = "app/assets/builds"
      config.sasso.source_map = nil   # resolved in `Sasso::Rails.source_map_for`

      # NOTE: no `rake_tasks do load ... end` — Rails::Engine already auto-loads
      # lib/tasks/**/*.rake into the host app. Loading it again here would define
      # each task (and run each `enhance`) twice.
    end

    module_function

    # Build a Compiler from the running app's config + root.
    def compiler(app = ::Rails.application)
      cfg = app.config.sasso
      Compiler.new(
        root:       app.root,
        builds:     cfg.builds,
        style:      style_for(cfg.style),
        load_paths: cfg.load_paths,
        source_dir: cfg.source_dir,
        build_dir:  cfg.build_dir,
        source_map: source_map_for(cfg.source_map),
      )
    end

    # Generate source maps outside production by default (debugging aid); an
    # explicit `config.sasso.source_map` (true/false) always wins. Off in
    # production by default to avoid shipping `.map` sidecars + the asset-digest
    # interaction unless opted in.
    def source_map_for(configured)
      return configured ? true : false unless configured.nil?

      !::Rails.env.production?
    end

    # Default to compressed CSS in production (smaller payload), expanded
    # elsewhere (readable). An explicit `config.sasso.style` always wins.
    #
    # If the asset pipeline has its own CSS compressor (a Sprockets app that set
    # config.assets.css_compressor), stay :expanded and let the pipeline
    # compress, avoiding wasteful double-minification. Propshaft sets no
    # compressor, so production stays :compressed on the default Rails 8 path.
    def style_for(configured)
      return configured.to_sym if configured
      return :expanded if pipeline_css_compressor?

      ::Rails.env.production? ? :compressed : :expanded
    end

    def pipeline_css_compressor?
      ::Rails.application&.config&.assets&.css_compressor.present?
    rescue StandardError
      false
    end
  end
end
