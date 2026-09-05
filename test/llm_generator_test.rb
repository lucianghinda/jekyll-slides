# frozen_string_literal: true

require "fileutils"
require "open3"
require "stringio"
require "tmpdir"
require_relative "test_helper"
require_relative "../bin/generate_llm"

class LlmGeneratorTest < Minitest::Test
  def setup
    @root = File.realpath(Dir.mktmpdir("jekyll-slides-llm"))
    @stdout = StringIO.new
    @stderr = StringIO.new
    @generator = LlmGenerator.new(root: @root, stdout: @stdout, stderr: @stderr)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_missing_main_document_fails_without_writing_output
    refute @generator.call
    assert_includes @stderr.string, "Missing #{@root}/doc/Jekyll/Slides.md"
    refute_path_exists File.join(@root, "llm.txt")
  end

  def test_sorted_nested_documentation_links_are_relative_to_each_output
    write("doc/Jekyll/Slides.md", "# Jekyll::Slides\n\nPlugin documentation.\n")
    write("doc/Jekyll/Slides/Renderer.md", "Renderer")
    write("doc/Jekyll/Slides/Parser/Node.md", "Node")
    write("doc/Jekyll/Slides/Assets.md", "Assets")

    assert @generator.call
    main = read("doc/Jekyll/Slides.md")
    assert_equal %w[Slides/Assets.md Slides/Parser/Node.md Slides/Renderer.md], main.scan(/^- \[([^\]]+)\]/).flatten
    assert_includes main, "[Slides/Parser/Node.md](Slides/Parser/Node.md)"
    assert_includes read("llm.txt"), "[Slides/Parser/Node.md](doc/Jekyll/Slides/Parser/Node.md)"
    assert_includes @stdout.string, "(3 links)"
  end

  def test_repeated_generation_replaces_duplicate_indexes_and_is_idempotent
    write("doc/Jekyll/Slides.md", "# Slides\n\n# Documentation\n\n- [old](Slides/Old.md)\n\n# Documentation\n\n- [older](Slides/Older.md)\n")
    write("doc/Jekyll/Slides/Assets.md", "Assets")

    assert @generator.call
    first = read("doc/Jekyll/Slides.md")
    assert_equal 1, first.scan(/^# Documentation$/).size
    refute_includes first, "Old"
    assert @generator.call
    assert_equal first, read("doc/Jekyll/Slides.md")
    assert_equal "\n", first[-1]
  end

  def test_rebases_relative_destinations_without_changing_unrelated_text
    content = <<~MARKDOWN
      # Slides

      [Renderer](Slides/Renderer.md#call), [Sibling](Other.md), [Parent](../Jekyll.md).
      [Web](https://example.com/Slides/Renderer.md), [Anchor](#methods), [Absolute](/guide.md).
      Slides/Renderer.md and `[Example](Slides/Renderer.md)` are code examples.

      ```markdown
      [Example](Slides/Renderer.md)
      ```

      # Documentation

      Authored explanation must survive.
    MARKDOWN
    write("doc/Jekyll/Slides.md", content)

    assert @generator.call
    llm = read("llm.txt")
    assert_includes llm, "[Renderer](doc/Jekyll/Slides/Renderer.md#call)"
    assert_includes llm, "[Sibling](doc/Jekyll/Other.md)"
    assert_includes llm, "[Parent](doc/Jekyll.md)"
    assert_includes llm, "[Web](https://example.com/Slides/Renderer.md)"
    assert_includes llm, "[Anchor](#methods), [Absolute](/guide.md)"
    assert_includes llm, "Slides/Renderer.md and `[Example](Slides/Renderer.md)`"
    assert_includes llm, "```markdown\n[Example](Slides/Renderer.md)\n```"
    assert_includes read("doc/Jekyll/Slides.md"), content.rstrip
  end

  def test_executable_uses_its_own_project_root_from_another_directory
    write("doc/Jekyll/Slides.md", "# Slides\n")
    write("bin/generate_llm.rb", File.read(File.expand_path("../bin/generate_llm.rb", __dir__)))

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, File.join(@root, "bin/generate_llm.rb"), chdir: File.dirname(@root))

    assert_predicate status, :success?, stderr
    assert_includes stdout, "Updated #{@root}/doc/Jekyll/Slides.md"
    assert File.file?(File.join(@root, "llm.txt"))
  end

  private

  def write(path, content)
    absolute_path = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(absolute_path))
    File.write(absolute_path, content)
  end

  def read(path)
    File.read(File.join(@root, path))
  end
end
