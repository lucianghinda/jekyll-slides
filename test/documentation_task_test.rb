# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

class DocumentationTaskTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_yard_replaces_stale_output_without_including_internal_plans
    Dir.mktmpdir do |root|
      %w[.yardopts Gemfile Gemfile.lock README.md Rakefile jekyll-slides.gemspec lib docs].each do |path|
        source = File.join(ROOT, path)
        FileUtils.cp_r(source, root) if File.exist?(source)
      end
      FileUtils.mkdir_p(File.join(root, "doc/docs/superpowers"))
      File.write(File.join(root, "doc/stale.md"), "stale")
      File.write(File.join(root, "doc/docs/superpowers/plan.md"), "private plan")
      %w[node_modules/vendor tmp/private examples].each do |path|
        FileUtils.mkdir_p(File.join(root, path))
        File.write(File.join(root, path, "README.md"), "not public API documentation")
      end
      output, error, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => File.join(root, "Gemfile") },
        RbConfig.ruby, "-S", "bundle", "exec", "rake", "yard", chdir: root
      )

      assert_predicate status, :success?, "YARD failed: #{output}\n#{error}"
      %w[doc/Jekyll/Slides.md doc/Jekyll/Slides/Presentation.md].each do |path|
        assert File.file?(File.join(root, path)), "missing #{path}"
      end
      refute_path_exists File.join(root, "doc/stale.md")
      refute_path_exists File.join(root, "doc/docs")
      %w[node_modules tmp examples].each { |path| refute_path_exists File.join(root, "doc", path) }
      refute_path_exists File.join(root, ".yardoc")
      Dir[File.join(root, "doc/**/*.md")].each do |document|
        File.read(document).scan(/\]\(([^)]+\.md)(?:#[^)]*)?\)/).flatten.each do |target|
          next if target.match?(%r{\A(?:[a-z]+:|/)}i)

          assert File.file?(File.expand_path(target, File.dirname(document))), "broken documentation link #{target} in #{document}"
        end
      end
    end
  end
end
