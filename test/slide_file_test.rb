# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

class SlideFileTest < Minitest::Test
  def write(dir, name, content)
    path = File.join(dir, name)
    File.write(path, content)
    path
  end

  def slide_file(path, warnings: [])
    Jekyll::Slides::SlideFile.new(path, warning: ->(message) { warnings << message })
  end

  def test_a_file_with_no_front_matter_is_left_byte_identical
    Dir.mktmpdir do |dir|
      content = "# One\n\n---\n\n# Two"
      path = write(dir, "slide.md", content)
      slides = slide_file(path).slides
      assert_equal ["# One", "# Two"], slides
    end
  end

  def test_a_file_holding_several_slides
    Dir.mktmpdir do |dir|
      path = write(dir, "slide.md", "# First\n\n---\n\n# Second\n\n---\n\n# Third")
      assert_equal ["# First", "# Second", "# Third"], slide_file(path).slides
    end
  end

  def test_file_front_matter_is_applied_as_defaults_to_every_slide
    Dir.mktmpdir do |dir|
      content = "---\nlayout: content\nbackground: grid\n---\n# First\n\n---\n\n# Second"
      path = write(dir, "slide.md", content)
      slides = slide_file(path).slides
      assert_equal "<!--\nlayout: content\nbackground: grid\n-->\n# First", slides[0]
      assert_equal "<!--\nlayout: content\nbackground: grid\n-->\n# Second", slides[1]
    end
  end

  def test_a_slides_own_comment_overrides_one_key_while_inheriting_another
    Dir.mktmpdir do |dir|
      content = "---\nlayout: content\nbackground: grid\n---\n<!--\nlayout: title\n-->\n# First"
      path = write(dir, "slide.md", content)
      slides = slide_file(path).slides
      assert_equal "<!--\nlayout: title\nbackground: grid\n-->\n# First", slides.first
    end
  end

  def test_unknown_front_matter_key_warns_and_is_dropped
    Dir.mktmpdir do |dir|
      content = "---\ntitle: My Slide\nlayout: content\n---\n# First"
      path = write(dir, "slide.md", content)
      warnings = []
      slides = slide_file(path, warnings: warnings).slides
      assert_equal ["<!--\nlayout: content\n-->\n# First"], slides
      assert_equal 1, warnings.length
      assert_includes warnings.first, "\"title\""
    end
  end

  def test_no_defaults_returns_the_slide_untouched
    Dir.mktmpdir do |dir|
      path = write(dir, "slide.md", "# Only slide")
      assert_equal ["# Only slide"], slide_file(path).slides
    end
  end

  def test_an_empty_file_warns_and_contributes_no_slides
    Dir.mktmpdir do |dir|
      path = write(dir, "empty.md", "")
      warnings = []
      slides = slide_file(path, warnings: warnings).slides
      assert_empty slides
      assert_equal 1, warnings.length
      assert_includes warnings.first, path
    end
  end

  def test_crlf_input_is_read_and_split_correctly
    Dir.mktmpdir do |dir|
      content = "---\r\nlayout: content\r\n---\r\n# First\r\n\r\n---\r\n\r\n# Second\r\n"
      path = write(dir, "slide.md", content)
      slides = slide_file(path).slides
      assert_equal 2, slides.length
      assert_equal "<!--\nlayout: content\n-->\n# First", slides[0]
      assert_equal "<!--\nlayout: content\n-->\n# Second", slides[1]
    end
  end
end
