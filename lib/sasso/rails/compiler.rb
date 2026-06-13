# frozen_string_literal: true

require "fileutils"

module Sasso
  module Rails
    # Compiles configured Sass/SCSS entrypoints to plain CSS files under the
    # builds directory. Deliberately Rails-free so it can be unit-tested with a
    # plain temp `root:` — the Engine just wires `Rails.root` and config in.
    #
    #   Sasso::Rails::Compiler.new(
    #     root:       Rails.root,
    #     builds:     { "application.scss" => "application.css" },
    #     style:      :expanded,
    #     load_paths: [],            # extra dirs, in addition to the source dir
    #     source_dir: "app/assets/stylesheets",
    #     build_dir:  "app/assets/builds",
    #   ).build
    class Compiler
      Error = Class.new(StandardError)

      ALLOWED_STYLES = %i[expanded compressed].freeze

      attr_reader :root, :builds, :style, :load_paths, :source_dir, :build_dir

      def initialize(root:, builds:, style: :expanded, load_paths: [],
                     source_dir: "app/assets/stylesheets",
                     build_dir: "app/assets/builds")
        @root       = File.expand_path(root.to_s)
        @builds     = normalize_builds(builds)
        @style      = normalize_style(style)
        @load_paths = Array(load_paths).map(&:to_s)
        @source_dir = source_dir.to_s
        @build_dir  = build_dir.to_s
      end

      # Compile every entrypoint; returns the list of written output paths.
      def build
        builds.map { |input, output| build_one(input, output) }
      end

      # Compile a single `input` (relative to source_dir) to `output` (relative
      # to build_dir), returning the absolute path written.
      def build_one(input, output)
        src = File.join(@root, @source_dir, input)
        unless File.file?(src)
          raise Error, "sasso-rails: input stylesheet not found: #{src}"
        end

        # `Sasso.compile` already searches the entry file's own directory first
        # (for sibling @use/@import); pass any extra include dirs after it.
        css = ::Sasso.compile(src, style: @style, load_paths: @load_paths)

        dest = File.join(@root, @build_dir, output)
        FileUtils.mkdir_p(File.dirname(dest))
        File.write(dest, css)
        dest
      end

      # Recompile whenever a watched source file changes. Dependency-free poll
      # loop (no `listen` gem): cheap mtime scan of the source + load_path trees.
      # Blocks. A compile error (including on the FIRST pass) is reported and the
      # loop keeps running — the watcher must survive a mid-edit broken file.
      def watch(interval: 1.0)
        safe_build
        snapshot = source_mtimes
        loop do
          sleep interval
          current = source_mtimes
          next if current == snapshot

          snapshot = current
          safe_build
        end
      end

      private

      # Compile, downgrading a Sass/config error to a warning so a watcher does
      # not die on it (used at startup and on every recompile).
      def safe_build
        build
      rescue ::Sasso::CompileError, Error => e
        warn e.message
      end

      # mtime of every .scss/.sass under the source dir AND the configured
      # load_paths (so editing a shared partial in an include dir also rebuilds).
      def source_mtimes
        dirs = [File.join(@root, @source_dir), *@load_paths]
        dirs.flat_map { |d| Dir.glob(File.join(d, "**", "*.{scss,sass}")) }
            .uniq.sort.each_with_object({}) do |f, h|
          h[f] = File.mtime(f).to_f
        rescue Errno::ENOENT
          # raced with a delete; skip
        end
      end

      # config.sasso.builds must be a non-empty { "input" => "output" } map.
      def normalize_builds(builds)
        hash = builds.respond_to?(:to_h) ? builds.to_h : nil
        if hash.nil? || hash.empty?
          raise Error, "sasso-rails: config.sasso.builds must be a non-empty Hash " \
                       'of { "input.scss" => "output.css" }'
        end
        hash
      end

      # Coerce + validate the style (nil/garbage gives a clear error, not a
      # NoMethodError or an opaque compiler ArgumentError).
      def normalize_style(style)
        sym = style.to_s.to_sym
        unless ALLOWED_STYLES.include?(sym)
          raise Error, "sasso-rails: config.sasso.style must be one of " \
                       "#{ALLOWED_STYLES.inspect}, got #{style.inspect}"
        end
        sym
      end
    end
  end
end
