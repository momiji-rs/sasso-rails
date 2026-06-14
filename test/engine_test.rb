# frozen_string_literal: true

require_relative "test_helper"
require "rails"
require "sasso/rails/engine"

class EngineTest < Minitest::Test
  include CompilerFixture

  # Minimal stand-in for Rails.application — avoids booting a full app.
  class FakeApp
    Config = Struct.new(:sasso)
    attr_reader :config, :root

    def initialize(root:, **opts)
      sasso = ActiveSupport::OrderedOptions.new
      sasso.builds     = opts.fetch(:builds, { "application.scss" => "application.css" })
      sasso.style      = opts[:style]
      sasso.load_paths = opts.fetch(:load_paths, [])
      sasso.source_dir = opts.fetch(:source_dir, "app/assets/stylesheets")
      sasso.build_dir  = opts.fetch(:build_dir, "app/assets/builds")
      @config = Config.new(sasso)
      @root   = root
    end
  end

  def test_explicit_style_wins
    assert_equal :compressed, Sasso::Rails.style_for(:compressed)
    assert_equal :expanded, Sasso::Rails.style_for("expanded")
  end

  def test_env_default_style_is_a_known_symbol
    assert_includes %i[expanded compressed], Sasso::Rails.style_for(nil)
  end

  def test_compiler_built_from_app_config_compiles
    with_app("application.scss" => ".a { b: 1px; }") do |root|
      compiler = Sasso::Rails.compiler(FakeApp.new(root: root))

      assert_instance_of Sasso::Rails::Compiler, compiler
      assert_equal File.expand_path(root), compiler.root
      compiler.build
      assert File.exist?(File.join(root, "app/assets/builds/application.css"))
    end
  end

  def test_engine_is_a_rails_engine
    assert_operator Sasso::Rails::Engine, :<, ::Rails::Engine
  end

  # When a Sprockets app set config.assets.css_compressor, default style backs
  # off to :expanded to avoid double-minification; an explicit pin still wins.
  def test_style_backs_off_when_css_compressor_present
    fake = Object.new
    cfg = ActiveSupport::OrderedOptions.new
    cfg.assets = ActiveSupport::OrderedOptions.new
    cfg.assets.css_compressor = :sass
    fake.define_singleton_method(:config) { cfg }

    ::Rails.stub(:application, fake) do
      assert_equal :expanded, Sasso::Rails.style_for(nil)
      assert_equal :compressed, Sasso::Rails.style_for(:compressed)
    end
  end

  # Source maps default on outside production; an explicit setting always wins.
  def test_source_map_default_is_env_based
    ::Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
      assert_equal true, Sasso::Rails.source_map_for(nil)
    end
    ::Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_equal false, Sasso::Rails.source_map_for(nil)
      assert_equal true, Sasso::Rails.source_map_for(true) # explicit override wins
    end
  end
end
