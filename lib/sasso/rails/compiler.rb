# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"

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

      attr_reader :root, :builds, :style, :load_paths, :source_dir, :build_dir, :source_map

      def initialize(root:, builds:, style: :expanded, load_paths: [],
                     source_dir: "app/assets/stylesheets",
                     build_dir: "app/assets/builds", source_map: false)
        @root       = File.expand_path(root.to_s)
        @builds     = normalize_builds(builds)
        @style      = normalize_style(style)
        @load_paths = Array(load_paths).map(&:to_s)
        @source_dir = source_dir.to_s
        @build_dir  = build_dir.to_s
        @source_map = source_map ? true : false
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

        dest = File.join(@root, @build_dir, output)
        FileUtils.mkdir_p(File.dirname(dest))

        # `Sasso.compile` already searches the entry file's own directory first
        # (for sibling @use/@import); pass any extra include dirs after it.
        if @source_map
          result = ::Sasso.compile(src, style: @style, load_paths: @load_paths, source_map: true)
          write_source_map(dest, result.source_map)
          File.write(dest, result.css + source_map_footer(File.basename(dest)))
        else
          # sasso >= 0.2.7's library API omits the trailing newline; a built CSS
          # artifact conventionally ends with one (and dart-sass's CLI writes it),
          # so append it here.
          File.write(dest, "#{::Sasso.compile(src, style: @style, load_paths: @load_paths)}\n")
        end
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

      # Write the sidecar `<dest>.map`, pointing `file` at the built CSS and
      # rewriting each source URL to a path relative to the builds directory
      # (the .map lives next to the CSS). `source_map` is the parsed v3 Hash.
      def write_source_map(dest, source_map)
        from_dir = File.dirname(dest)
        source_map["file"] = File.basename(dest)
        source_map["sources"] = Array(source_map["sources"]).map { |s| relative_source(s, from_dir) }
        File.write("#{dest}.map", JSON.generate(source_map))
      end

      # The `sourceMappingURL` footer for the built CSS. Matches dart-sass: since
      # sasso >= 0.2.7's `result.css` has no trailing newline, the expanded
      # footer supplies the line terminator AND dart's blank separator line
      # (`\n\n`); the compressed footer is appended directly (no leading newline).
      def source_map_footer(css_basename)
        comment = "/*# sourceMappingURL=#{css_basename}.map */"
        @style == :compressed ? "#{comment}\n" : "\n\n#{comment}\n"
      end

      # A source URL made relative to the .map's directory (so a DevTools that
      # loads the .map resolves the original next to it). Falls back to the URL
      # unchanged if it is not a relativizable path.
      def relative_source(url, from_dir)
        Pathname.new(url).relative_path_from(Pathname.new(from_dir)).to_s
      rescue ArgumentError
        url
      end

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
