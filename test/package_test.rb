# frozen_string_literal: true

require "fileutils"
require "rubygems/package"
require "tmpdir"
require_relative "test_helper"

class PackageTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SPEC_PATH = File.join(ROOT, "jekyll-slides.gemspec")

  def setup
    @spec = Gem::Specification.load(SPEC_PATH)
    refute_nil @spec, "gemspec should load"
  end

  def test_metadata_and_runtime_dependency
    assert_equal "jekyll-slides", @spec.name
    assert_equal Jekyll::Slides::VERSION, @spec.version.to_s
    assert_equal "Apache-2.0", @spec.license
    license = File.read(File.join(ROOT, "LICENSE.txt"))
    assert_operator license.length, :>, 10_000
    %w[Apache License Version 2.0 January 2004 TERMS AND CONDITIONS END OF TERMS AND CONDITIONS].each do |phrase|
      assert_includes license, phrase
    end
    assert_operator @spec.required_ruby_version, :===, Gem::Version.new("3.1")
    assert_operator @spec.required_ruby_version, :===, Gem::Version.new("4.0")

    jekyll = @spec.runtime_dependencies.find { |dependency| dependency.name == "jekyll" }
    refute_nil jekyll
    refute jekyll.requirement.satisfied_by?(Gem::Version.new("4.2"))
    assert_operator jekyll.requirement, :===, Gem::Version.new("4.4")
    assert_operator jekyll.requirement, :===, Gem::Version.new("4.3")
    refute jekyll.requirement.satisfied_by?(Gem::Version.new("5.0"))

    %w[kramdown kramdown-parser-gfm rouge].each do |name|
      assert @spec.runtime_dependencies.any? { |dependency| dependency.name == name }, "missing direct #{name} dependency"
    end
    assert_includes @spec.description, "plugin"
    refute_includes @spec.description, "theme"
  end

  def test_shipped_files_include_runtime_surface_and_exclude_development_artifacts
    required = %w[
      _layouts/presentation.html
      _includes/slides/controls.html
      _includes/slides/overview.html
      _includes/slides/progress.html
      assets/css/presentation.css
      assets/js/presentation.js
      lib/jekyll-slides.rb
      lib/jekyll/slides.rb
      lib/jekyll/slides/assets.rb
      lib/jekyll/slides/layout.rb
      lib/jekyll/slides/renderer.rb
      lib/jekyll/slides/version.rb
      README.md
      CHANGELOG.md
      LICENSE.txt
    ]
    required.each { |path| assert_includes @spec.files, path }
    refute_includes @spec.files, "_config.yml"
    assert_empty @spec.require_paths - ["lib"]

    @spec.files.each do |path|
      refute_match(%r{(?:\A|/)(?:node_modules|tmp|pkg|\.jekyll-cache)(?:/|\z)}, path)
      refute_match(/(?:package-lock\.json|\.gem\z|\.log\z)/, path)
      assert File.file?(File.join(ROOT, path)), "missing shipped file #{path}"
    end
  end

  def test_project_conventions_are_present
    %w[.ruby-version .rubocop.yml CHANGELOG.md .github/workflows/ci.yml].each do |path|
      assert File.file?(File.join(ROOT, path)), "missing #{path}"
    end
  end

  def test_generated_documentation_is_shipped_without_release_tools
    %w[llms.txt doc/Jekyll/Slides.md doc/Jekyll/Slides/Presentation.md].each do |path|
      assert_includes @spec.files, path
      assert File.file?(File.join(ROOT, path)), "missing generated documentation #{path}"
    end
    refute_includes @spec.files, "bin/prepare_release"
    refute_includes @spec.files, "bin/generate_llm.rb"
    refute(@spec.runtime_dependencies.any? { |dependency| %w[yard yard-markdown].include?(dependency.name) })
  end

  def test_bundled_fonts_are_shipped_with_their_licenses_and_provenance
    %w[next mono].each do |family|
      %w[normal italic].each do |style|
        suffix = style == "italic" ? "-italic" : ""
        path = "assets/fonts/atkinson-hyperlegible-#{family}#{suffix}.woff2"
        assert_includes @spec.files, path
        data = File.binread(File.join(ROOT, path))
        assert_equal "wOF2", data.byteslice(0, 4)
        assert_operator data.bytesize, :>, 10_000
      end

      path = "assets/fonts/OFL-atkinson-hyperlegible-#{family}.txt"
      assert_includes @spec.files, path
      assert_includes File.read(File.join(ROOT, path)), "SIL OPEN FONT LICENSE Version 1.1"
    end

    assert_includes @spec.files, "assets/fonts/README.md"
    assert_includes File.read(File.join(ROOT, "assets/fonts/README.md")), "SHA-256"
  end

  def test_gem_build_has_the_same_safe_contents
    Dir.mktmpdir("jekyll-slides-gem") do |directory|
      built = File.join(directory, @spec.file_name)
      Gem::Package.build(@spec, false, true, built)
      assert File.file?(built)

      entries = Gem::Package.new(built).contents
      assert_includes entries, "_layouts/presentation.html"
      assert_includes entries, "assets/css/presentation.css"
      assert_includes entries, "LICENSE.txt"
      refute(entries.any? { |entry| entry.match?(%r{(?:node_modules|tmp|pkg)/}) })
    end
  end
end
