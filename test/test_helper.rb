# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"   # Object#stub
require "tmpdir"
require "fileutils"

# Loads sasso + version + Compiler. The Engine is only required when Rails is
# present, so these unit tests exercise the Compiler without booting Rails.
require "sasso/rails"

module CompilerFixture
  # Yields an absolute `root` containing app/assets/stylesheets/<files>.
  def with_app(stylesheets)
    Dir.mktmpdir do |root|
      dir = File.join(root, "app/assets/stylesheets")
      FileUtils.mkdir_p(dir)
      stylesheets.each do |name, content|
        path = File.join(dir, name)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end
      yield root
    end
  end

  def read_build(root, output)
    File.read(File.join(root, "app/assets/builds", output))
  end
end
