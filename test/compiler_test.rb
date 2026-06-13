# frozen_string_literal: true

require_relative "test_helper"

class CompilerTest < Minitest::Test
  include CompilerFixture

  def test_version_is_defined
    assert_match(/\A\d+\.\d+\.\d+/, Sasso::Rails::VERSION)
  end

  def test_compiles_entrypoint_to_builds_dir
    with_app("application.scss" => ".a { .b { color: red; } }") do |root|
      written = Sasso::Rails::Compiler.new(
        root: root, builds: { "application.scss" => "application.css" }
      ).build

      assert_equal [File.join(root, "app/assets/builds/application.css")], written
      css = read_build(root, "application.css")
      assert_includes css, ".a .b {"
      assert_includes css, "color: red;"
    end
  end

  def test_resolves_sibling_partial_via_use
    files = {
      "_tokens.scss"    => "$brand: #3366cc;",
      "application.scss" => %(@use "tokens" as t;\n.btn { color: t.$brand; }\n),
    }
    with_app(files) do |root|
      Sasso::Rails::Compiler.new(
        root: root, builds: { "application.scss" => "application.css" }
      ).build
      assert_includes read_build(root, "application.css"), "color: #3366cc;"
    end
  end

  def test_compressed_style
    with_app("application.scss" => ".a { width: 10px; .b { height: 2px } }") do |root|
      Sasso::Rails::Compiler.new(
        root: root, builds: { "application.scss" => "application.css" }, style: :compressed
      ).build
      assert_equal ".a{width:10px}.a .b{height:2px}", read_build(root, "application.css")
    end
  end

  def test_extra_load_paths_are_honored
    files = { "application.scss" => %(@use "shared" as s;\n.x { margin: s.$gap; }\n) }
    with_app(files) do |root|
      shared = File.join(root, "vendor/styles")
      FileUtils.mkdir_p(shared)
      File.write(File.join(shared, "_shared.scss"), "$gap: 12px;")

      Sasso::Rails::Compiler.new(
        root: root, builds: { "application.scss" => "application.css" }, load_paths: [shared]
      ).build
      assert_includes read_build(root, "application.css"), "margin: 12px;"
    end
  end

  def test_multiple_entrypoints
    files = {
      "application.scss" => ".a { x: 1 }",
      "admin.scss"       => ".b { y: 2 }",
    }
    with_app(files) do |root|
      Sasso::Rails::Compiler.new(
        root: root,
        builds: { "application.scss" => "application.css", "admin.scss" => "admin.css" }
      ).build
      assert_includes read_build(root, "application.css"), "x: 1;"
      assert_includes read_build(root, "admin.css"), "y: 2;"
    end
  end

  def test_missing_input_raises_clear_error
    with_app({}) do |root|
      err = assert_raises(Sasso::Rails::Compiler::Error) do
        Sasso::Rails::Compiler.new(
          root: root, builds: { "missing.scss" => "missing.css" }
        ).build
      end
      assert_match(/input stylesheet not found/, err.message)
    end
  end

  def test_compile_error_propagates
    with_app("application.scss" => ".a { color: ; }") do |root|
      assert_raises(Sasso::CompileError) do
        Sasso::Rails::Compiler.new(
          root: root, builds: { "application.scss" => "application.css" }
        ).build
      end
    end
  end

  def test_rejects_empty_or_non_hash_builds
    with_app({}) do |root|
      [nil, {}].each do |bad|
        err = assert_raises(Sasso::Rails::Compiler::Error) do
          Sasso::Rails::Compiler.new(root: root, builds: bad)
        end
        assert_match(/non-empty Hash/, err.message)
      end
    end
  end

  def test_rejects_unknown_style
    with_app({}) do |root|
      err = assert_raises(Sasso::Rails::Compiler::Error) do
        Sasso::Rails::Compiler.new(
          root: root, builds: { "a.scss" => "a.css" }, style: :nested
        )
      end
      assert_match(/config\.sasso\.style/, err.message)
    end
  end

  # The watcher must survive a compile error even on its very first pass — verify
  # the shared safe-build path swallows it (the full loop blocks, so we exercise
  # the private helper directly rather than spin the loop).
  def test_safe_build_swallows_compile_error
    with_app("application.scss" => ".a { color: ; }") do |root|
      compiler = Sasso::Rails::Compiler.new(
        root: root, builds: { "application.scss" => "application.css" }
      )
      out, err = capture_io { compiler.send(:safe_build) }
      assert_empty out
      assert_match(/Error/, err)
    end
  end
end
