# frozen_string_literal: true

require "rails/generators/base"

module Sasso
  module Generators
    # `bin/rails sasso:install` — scaffolds the entrypoint + build dir and wires
    # a dev watch process, mirroring the dartsass/tailwindcss install flow.
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      # A fresh Propshaft/Sprockets app ships app/assets/stylesheets/application.css.
      # Our compiled output is app/assets/builds/application.css — both resolve to
      # the logical path "application.css" on the asset load path, which collides.
      # The build dir owns the compiled CSS now (the cssbundling convention), so
      # drop the default stub.
      def remove_default_application_css
        default = "app/assets/stylesheets/application.css"
        remove_file default if File.exist?(File.join(destination_root, default))
      end

      def create_stylesheet
        template "application.scss", "app/assets/stylesheets/application.scss"
      end

      # Rails 8 layouts default to `stylesheet_link_tag :app`, which looks for
      # "app.css" and won't pick up our compiled "application.css". Point it at
      # the entrypoint we build. No-op if the layout is missing or already links
      # "application" (so a customized layout is left alone).
      def link_stylesheet_in_layout
        layout = "app/views/layouts/application.html.erb"
        full = File.join(destination_root, layout)
        return unless File.exist?(full)
        return if File.read(full).include?('stylesheet_link_tag "application"')

        gsub_file layout, /stylesheet_link_tag\s+:app\b/, 'stylesheet_link_tag "application"'
      end

      def ensure_builds_directory
        create_file "app/assets/builds/.keep" unless File.exist?(builds_keep_path)

        rules = "/app/assets/builds/*\n!/app/assets/builds/.keep\n"
        if File.exist?(gitignore_path)
          # Idempotent: skip if already present (re-running the installer).
          append_to_file ".gitignore", rules unless File.read(gitignore_path).include?("/app/assets/builds/")
        else
          # No .gitignore at all — create one so generated CSS isn't committed.
          create_file ".gitignore", rules
        end
      end

      # Sprockets-only apps must link the builds directory in the manifest;
      # Propshaft discovers it automatically, so guard on the manifest existing.
      def link_builds_in_sprockets_manifest
        manifest = "app/assets/config/manifest.js"
        full = File.join(destination_root, manifest)
        return unless File.exist?(full)

        unless File.read(full).include?("link_tree ../builds")
          append_to_file manifest, %(//= link_tree ../builds\n)
        end

        # The default Sprockets manifest links the stylesheets SOURCE directory
        # (`//= link_directory ../stylesheets .css`). Sprockets 4 then tries to
        # COMPILE our `application.scss` entrypoint with its built-in
        # SasscProcessor, which `require "sassc"` — not installed on a default
        # app — so `assets:precompile` crashes with
        # `LoadError: cannot load such file -- sassc`. sasso owns the compiled
        # output (served from ../builds, linked above), so the raw source dir
        # must NOT be linked. Neutralize the directive — idempotent, since the
        # regex only matches the live `//=` form (a re-run is a no-op).
        gsub_file manifest,
                  %r{^([ \t]*)//=([ \t]*link_directory[ \t]+\.\./stylesheets\b.*)$},
                  "\\1//\\2  -- disabled by sasso-rails (sasso compiles ../stylesheets to ../builds; " \
                  "linking the source dir makes Sprockets compile .scss via sassc)"
      end

      def add_watch_to_procfile
        procfile = "Procfile.dev"
        full = File.join(destination_root, procfile)
        if File.exist?(full)
          append_to_file procfile, "css: bin/rails sasso:watch\n" unless File.read(full).include?("sasso:watch")
        else
          create_file procfile, <<~PROCFILE
            web: bin/rails server
            css: bin/rails sasso:watch
          PROCFILE
        end
      end

      # Compile once so `app/assets/builds/application.css` exists and the first
      # page load (stylesheet_link_tag "application") doesn't 404.
      def build_initial_css
        rails_command "sasso:build"
      end

      def print_instructions
        say ""
        say "sasso-rails installed.", :green
        say "  • Edit app/assets/stylesheets/application.scss"
        say "  • Reference it with: <%= stylesheet_link_tag \"application\" %>"
        say "  • Build once:   bin/rails sasso:build"
        say "  • Watch in dev: bin/rails sasso:watch"
        say "    (or ./bin/dev, if your app has a Procfile.dev runner like foreman)"
      end

      private

      def builds_keep_path
        File.join(destination_root, "app/assets/builds/.keep")
      end

      def gitignore_path
        File.join(destination_root, ".gitignore")
      end
    end
  end
end
