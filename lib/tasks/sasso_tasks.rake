# frozen_string_literal: true

namespace :sasso do
  desc "Compile the configured Sass/SCSS entrypoints to app/assets/builds"
  task build: :environment do
    written = Sasso::Rails.compiler.build
    written.each { |path| puts "sasso: compiled #{path}" }
  end

  desc "Watch the source stylesheets and recompile on change (Ctrl-C to stop)"
  task watch: :environment do
    compiler = Sasso::Rails.compiler
    puts "sasso: watching #{compiler.source_dir} ..."
    compiler.watch
  rescue Interrupt
    puts "\nsasso: stopped."
  end

  desc "Remove the CSS that sasso:build generated"
  task clobber: :environment do
    compiler = Sasso::Rails.compiler
    compiler.builds.each_value do |output|
      path = File.join(compiler.root, compiler.build_dir, output)
      next unless File.exist?(path)

      File.delete(path)
      puts "sasso: removed #{path}"
    end
  end
end

# Generate CSS before the asset pipeline (Propshaft/Sprockets) digests it, and
# before the test DB/fixtures are prepared so system/feature tests see fresh CSS.
# Set SKIP_CSS_BUILD=1 to opt out (Docker multi-stage / separate build step).
unless ENV["SKIP_CSS_BUILD"]
  if Rake::Task.task_defined?("assets:precompile")
    Rake::Task["assets:precompile"].enhance(["sasso:build"])
  end

  # Hook whichever test-prep task this app defines (Minitest / RSpec / DB-only).
  %w[test:prepare spec:prepare db:test:prepare].each do |t|
    next unless Rake::Task.task_defined?(t)

    Rake::Task[t].enhance(["sasso:build"])
    break
  end
end

# Keep `rails assets:clobber` symmetric.
if Rake::Task.task_defined?("assets:clobber")
  Rake::Task["assets:clobber"].enhance(["sasso:clobber"])
end
