# frozen_string_literal: true

require "open3"
require "rubygems/installer"
require "rubygems/package"
require "tmpdir"
require_relative "test_helper"

class ExamplePresentationTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  EXAMPLES = File.join(ROOT, "examples")

  def test_beautiful_ruby_build_uses_the_installed_plugin_in_a_fresh_process
    Dir.mktmpdir("jekyll-slides-example") do |directory|
      gem_home = File.join(directory, "gem-home")
      destination = File.join(directory, "site")
      gem_file = build_and_install_gem(directory, gem_home)
      stdout, stderr, status = run_installed_build(gem_home, gem_file, destination)

      assert_predicate status, :success?, "installed-gem build failed:\n#{stdout}\n#{stderr}"
      output_path = File.join(destination, "beautiful-ruby", "index.html")
      assert File.file?(output_path), "expected generated beautiful-ruby page"
      output = File.read(output_path)

      assert_equal 10, output.scan('<section class="slide ').length
      assert_includes output, 'data-theme="midnight"'
      assert_includes output, 'data-aspect-ratio="16:9"'
      assert_includes output, 'data-progress="true"'
      assert_includes output, 'data-slide-numbers="true"'
      assert_includes output, "data-overview"
      assert_includes output, "data-slide-fullscreen"
      assert_includes output, 'href="/assets/css/presentation.css"'
      assert_includes output, 'src="/assets/js/presentation.js"'
      assert_includes output, 'aria-label="Previous slide"'
      assert_includes output, 'aria-label="Next slide"'
      %w[layout-title layout-statement layout-code layout-code-right layout-split-code layout-code-result layout-content].each do |layout|
        assert_includes output, layout
      end
      %w[bg-gradient bg-spotlight bg-grid bg-plain].each do |background|
        assert_includes output, background
      end
      %w[code-window terminal-window code-window-header slide-progress slide-counter overview-hint].each do |component|
        assert_includes output, component
      end
      assert_includes output, "refactor"
      assert_includes output, '<span class="n">_1</span><span class="p">.</span><span class="nf">subtotal</span>'
      assert_includes output, "bundle exec rspec"
      refute_includes output, "<hr"
      refute_includes output, "{%"
      refute_includes output, "@apply"
      refute_includes output, "class=\"highlighter-rouge\""
      assert File.file?(File.join(destination, "assets/css/presentation.css"))
      assert File.file?(File.join(destination, "assets/js/presentation.js"))
      assert_installed_fonts(destination)
      light_output = File.read(File.join(destination, "readability", "index.html"))
      assert_equal 5, light_output.scan('<section class="slide ').length
      assert_includes light_output, 'data-theme="minimal-light"'
      %w[code-window terminal-window table blockquote footnotes].each do |component|
        assert_includes light_output, component
      end
      assert_includes light_output, "<em>real italics</em>"
    end
  end

  private

  def assert_installed_fonts(destination)
    %w[next mono].each do |family|
      %w[normal italic].each do |style|
        suffix = style == "italic" ? "-italic" : ""
        path = "assets/fonts/atkinson-hyperlegible-#{family}#{suffix}.woff2"
        assert File.file?(File.join(destination, path)), "missing installed font #{path}"
        data = File.binread(File.join(destination, path))
        assert_equal "wOF2", data.byteslice(0, 4)
        assert_equal File.binread(File.join(ROOT, path)), data
      end

      license = File.join(destination, "assets/fonts/OFL-atkinson-hyperlegible-#{family}.txt")
      assert File.file?(license), "missing installed font license"
      assert_includes File.read(license), "SIL OPEN FONT LICENSE Version 1.1"
    end
  end

  def build_and_install_gem(directory, gem_home)
    spec = Gem::Specification.load(File.join(ROOT, "jekyll-slides.gemspec"))
    gem_file = File.join(directory, "jekyll-slides-#{spec.version}.gem")
    Gem::Package.build(spec, false, false, gem_file)
    Gem::Installer.new(
      Gem::Package.new(gem_file),
      install_dir: gem_home,
      wrappers: false,
      ignore_dependencies: true
    ).install
    gem_file
  end

  def run_installed_build(gem_home, gem_file, destination)
    dependency_paths = Gem.path
    environment = {
      "GEM_HOME" => gem_home,
      "GEM_PATH" => ([gem_home] + dependency_paths).join(File::PATH_SEPARATOR),
      "JSLIDES_EXPECTED_ROOT" => File.realpath(File.join(gem_home, "gems", Gem::Package.new(gem_file).spec.full_name)),
      "JSLIDES_EXAMPLES" => EXAMPLES,
      "JSLIDES_DESTINATION" => destination,
      "RUBYLIB" => nil,
      "RUBYOPT" => nil,
      "BUNDLE_GEMFILE" => nil
    }
    Open3.capture3(environment, RbConfig.ruby, "-e", <<~RUBY, chdir: Dir.tmpdir)
      require "rubygems"
      require "jekyll"
      require "jekyll-slides"

      installed = Gem::Specification.find_by_name("jekyll-slides")
      abort "wrong gem root: \#{installed.full_gem_path}" unless File.realpath(installed.full_gem_path) == ENV.fetch("JSLIDES_EXPECTED_ROOT")
      abort "checkout lib leaked into load path" if $LOAD_PATH.any? { |path| path == #{File.join(ROOT, 'lib').inspect} }

      config = Jekyll.configuration(
        "source" => ENV.fetch("JSLIDES_EXAMPLES"),
        "destination" => ENV.fetch("JSLIDES_DESTINATION"),
        "quiet" => true,
        "disable_disk_cache" => true
      )
      Jekyll::Site.new(config).process
    RUBY
  end
end
