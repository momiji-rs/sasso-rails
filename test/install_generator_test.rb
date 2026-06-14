# frozen_string_literal: true

require "test_helper"
require "rails"
require "rails/generators"
require "generators/sasso/install/install_generator"

# Unit-tests the Sprockets-manifest step of `rails generate sasso:install` in
# isolation (without booting a full Rails app or running `sasso:build`): it must
# link the builds dir AND neutralize the default `link_directory ../stylesheets`
# directive, which otherwise makes Sprockets 4 compile our `.scss` entrypoint
# with its built-in sassc processor and crash `assets:precompile`.
class InstallGeneratorManifestTest < Minitest::Test
  DEFAULT_MANIFEST = "//= link_tree ../images\n//= link_directory ../stylesheets .css\n"

  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, "app/assets/config"))
    File.write(manifest_path, DEFAULT_MANIFEST)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def manifest_path
    File.join(@root, "app/assets/config/manifest.js")
  end

  def manifest
    File.read(manifest_path)
  end

  def run_manifest_step
    gen = Sasso::Generators::InstallGenerator.new([], {}, destination_root: @root)
    capture_io { gen.link_builds_in_sprockets_manifest }
  end

  def test_links_builds_and_neutralizes_stylesheets_link_directory
    run_manifest_step

    assert_includes manifest, "//= link_tree ../builds",
                    "compiled output dir must be linked"
    refute_match(%r{^\s*//=\s*link_directory\s+\.\./stylesheets}, manifest,
                 "the live `//= link_directory ../stylesheets` directive must be neutralized")
    # the original line survives as an inert `//` comment (informative, ignored
    # by Sprockets which only honours `//=` directives)
    assert_match(%r{^\s*//\s*link_directory\s+\.\./stylesheets.*disabled by sasso-rails}, manifest)
    # the unrelated images directive is left intact
    assert_includes manifest, "//= link_tree ../images"
  end

  def test_idempotent
    run_manifest_step
    once = manifest
    run_manifest_step
    assert_equal once, manifest, "re-running the installer must be a no-op"
  end

  def test_no_op_without_manifest_propshaft
    # Propshaft apps have no manifest.js — the step must do nothing and not raise.
    FileUtils.rm_f(manifest_path)
    run_manifest_step
    refute File.exist?(manifest_path), "must not create a manifest on a Propshaft app"
  end
end
