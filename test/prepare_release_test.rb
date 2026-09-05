# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "fileutils"
require "rubygems/package"
require "digest"

script = File.expand_path("../bin/prepare_release", __dir__)
load script if File.file?(script)

class PrepareReleaseTest < Minitest::Test
  def setup
    assert defined?(ReleasePreparer), "expected bin/prepare_release to provide ReleasePreparer"
  end

  def test_runs_full_verification_and_documentation_before_building
    events = []
    runner = ->(command, root) { events << [command, root] }
    builder = ->(root) { events << [:build, root] }

    assert ReleasePreparer.new(root: "/project", ruby: "/ruby", runner: runner, builder: builder).call
    assert_equal commands.map { |command| [command, "/project"] } + [[:build, "/project"]], events
  end

  def test_stops_at_each_failed_stage_without_building
    commands.each_index do |failure|
      calls = []
      stderr = StringIO.new
      runner = lambda do |command, _root|
        calls << command
        command != commands.fetch(failure)
      end
      builder = ->(_root) { flunk "must not build after a failed command" }

      refute ReleasePreparer.new(root: "/project", ruby: "/ruby", runner: runner, builder: builder, stderr: stderr).call
      assert_equal commands.first(failure + 1), calls
      assert_includes stderr.string, commands.fetch(failure).join(" ")
    end
  end

  def test_reports_a_failed_or_invalid_build
    [->(_root) { false }, ->(_root) { raise Gem::InvalidSpecificationException, "invalid gem" }].each do |builder|
      stderr = StringIO.new

      refute ReleasePreparer.new(runner: ->(*) { true }, builder: builder, stderr: stderr).call
      assert_includes stderr.string, "Release preparation failed"
    end
  end

  def test_builds_the_versioned_package_and_checksum_in_the_project
    Dir.mktmpdir do |root|
      File.write(File.join(root, "README.md"), "release fixture\n")
      File.write(File.join(root, "jekyll-slides.gemspec"), <<~RUBY)
        Gem::Specification.new do |spec|
          spec.name = "jekyll-slides"
          spec.version = "9.8.7"
          spec.authors = ["Fixture"]
          spec.summary = "A release fixture"
          spec.homepage = "https://example.org"
          spec.license = "Apache-2.0"
          spec.required_ruby_version = ">= 3.1"
          spec.files = ["README.md"]
        end
      RUBY

      assert ReleasePreparer.new(root: root, runner: ->(*) { true }).call
      path = File.join(root, "pkg/jekyll-slides-9.8.7.gem")
      assert File.file?(path)
      assert_equal ["README.md"], Gem::Package.new(path).contents
      assert_equal "#{Digest::SHA256.file(path).hexdigest}  jekyll-slides-9.8.7.gem\n", File.read("#{path}.sha256")
    end
  end

  private

  def commands
    [
      ["/ruby", "-S", "bundle", "exec", "rake"],
      ["/ruby", "-S", "bundle", "exec", "rake", "yard"],
      ["/ruby", "/project/bin/generate_llm.rb"]
    ]
  end
end
