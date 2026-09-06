# frozen_string_literal: true

require_relative "test_helper"

class FrontMatterTest < Minitest::Test
  def split(source)
    Jekyll::Slides::FrontMatter.split(source)
  end

  def test_splits_a_well_formed_front_matter_block
    values, body = split("---\ntitle: Demo\nlayout: presentation\n---\n# One")
    assert_equal({ "title" => "Demo", "layout" => "presentation" }, values)
    assert_equal "# One", body
  end

  def test_accepts_crlf_line_endings
    values, body = split("---\r\ntitle: Demo\r\n---\r\n# One\r\n")
    assert_equal({ "title" => "Demo" }, values)
    assert_equal "# One\r\n", body
  end

  def test_empty_front_matter_block_yields_empty_values_and_the_body
    values, body = split("---\n---\n# One")
    assert_equal({}, values)
    assert_equal "# One", body
  end

  def test_source_without_a_leading_dashes_block_is_returned_unchanged
    source = "# One\n---\n# Two"
    values, body = split(source)
    assert_equal({}, values)
    assert_equal source, body
  end

  def test_unterminated_front_matter_block_is_returned_unchanged
    source = "---\ntitle: Demo\n# One"
    values, body = split(source)
    assert_equal({}, values)
    assert_equal source, body
  end

  def test_front_matter_that_does_not_parse_to_a_hash_is_returned_unchanged
    source = "---\n- not: a mapping\n---\n# One"
    values, body = split(source)
    assert_equal({}, values)
    assert_equal source, body
  end

  def test_invalid_yaml_is_returned_unchanged
    source = "---\ntitle: [unterminated\n---\n# One"
    values, body = split(source)
    assert_equal({}, values)
    assert_equal source, body
  end

  def test_front_matter_with_permitted_date_types_parses
    values, body = split("---\ndate: 2026-09-04\n---\n# One")
    assert_equal Date.new(2026, 9, 4), values["date"]
    assert_equal "# One", body
  end
end
