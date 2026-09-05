# frozen_string_literal: true

require_relative "test_helper"

class PresentationParserTest < Minitest::Test
  def parse(body)
    Jekyll::Slides::PresentationParser.new(body).parse
  end

  def test_splits_exact_separator_and_ignores_blank_slides
    assert_equal ["# One", "# Two"], parse("# One\n---\n\n---\n# Two\n")
  end

  def test_strips_leading_front_matter
    body = "---\ntitle: Demo\nlayout: slides\n---\n# One\n---\n# Two"
    assert_equal ["# One", "# Two"], parse(body)
  end

  def test_does_not_split_horizontal_rule_inside_fenced_code
    body = "# One\n```text\n---\n```\n---\n# Two"
    assert_equal ["# One\n```text\n---\n```", "# Two"], parse(body)
  end

  def test_separator_must_not_have_surrounding_spaces
    assert_equal ["one\n --- \ntwo"], parse("one\n --- \ntwo")
  end

  def test_four_backtick_fence_does_not_close_on_three_backticks
    body = "Before\n````ruby\n```\n---\n````\n---\nAfter"
    slides = parse(body)
    assert_equal 2, slides.length
    assert_includes slides.first, "---"
  end

  def test_front_matter_with_date_is_stripped
    body = "---\ndate: 2026-09-04\ntitle: Demo\n---\n# One\n---\n# Two"
    assert_equal ["# One", "# Two"], parse(body)
  end

  def test_invalid_front_matter_remains_content
    body = "---\n- not: a mapping\n---\n# One"
    assert_equal [body], parse(body)
  end

  def test_preserves_one_entry_and_empty_front_matter
    assert_equal ["# One"], parse("---\ntitle: Demo\n---\n# One")
    assert_equal ["# One"], parse("---\n---\n# One")
  end

  def test_preserves_invalid_final_entry_and_unterminated_front_matter
    invalid = "---\ntitle: [unterminated\n---\n# One"
    unterminated = "---\ntitle: Demo\n# One"
    assert_equal [invalid], parse(invalid)
    assert_equal [unterminated], parse(unterminated)
  end

  def test_preserves_indentation_and_trailing_hard_break_spaces
    source = "  indented\nline  \n---\nnext"
    assert_equal ["  indented\nline  ", "next"], parse(source)
  end

  def test_exact_setext_underline_is_a_slide_separator
    assert_equal ["Setext title", "Following content"], parse("Setext title\n---\nFollowing content")
  end
end
