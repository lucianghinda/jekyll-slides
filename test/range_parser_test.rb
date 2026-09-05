# frozen_string_literal: true

require_relative "test_helper"

class RangeParserTest < Minitest::Test
  def test_parses_ranges_uniquely_and_sorted
    assert_equal [2, 3, 4, 5, 6, 9], Jekyll::Slides::RangeParser.parse("2,4-6,9,3")
  end

  def test_invalid_value_returns_empty
    warnings = []
    assert_equal [], Jekyll::Slides::RangeParser.parse("0,2-x", warning: ->(message) { warnings << message })
    refute_empty warnings
  end

  def test_blank_value_returns_empty_without_error
    assert_equal [], Jekyll::Slides::RangeParser.parse(nil)
  end

  def test_malformed_commas_return_empty_and_warn
    ["2,", ",2", "2,,3"].each do |value|
      warnings = []
      assert_equal [], Jekyll::Slides::RangeParser.parse(value, warning: ->(message) { warnings << message })
      refute_empty warnings
    end
  end

  def test_rejects_adversarially_large_ranges_without_expanding
    warnings = []
    assert_equal [], Jekyll::Slides::RangeParser.parse("1-999999999", warning: ->(message) { warnings << message })
    refute_empty warnings
  end

  def test_rejects_ranges_when_cumulative_span_exceeds_budget
    warnings = []
    value = "1-50000,50001-100000,1-50000"
    assert_equal [], Jekyll::Slides::RangeParser.parse(value, warning: ->(message) { warnings << message })
    refute_empty warnings
  end
end
