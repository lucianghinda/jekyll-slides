# frozen_string_literal: true

require_relative "test_helper"

class SupportNaturalSortTest < Minitest::Test
  def sorted(names)
    names.sort_by { |name| Jekyll::Slides::Support.natural_sort_key(name) }
  end

  def test_numeric_prefixes_order_numerically_not_lexically
    names = %w[10-end.md 02-idea.md 01-intro.md appendix.md]
    assert_equal %w[01-intro.md 02-idea.md 10-end.md appendix.md], sorted(names)
  end

  def test_single_digit_prefix_orders_before_two_digit_prefix_numerically
    assert_equal %w[2-a.md 10-b.md], sorted(%w[10-b.md 2-a.md])
  end

  def test_zero_padded_and_unpadded_equal_numbers_order_deterministically
    first_pass = sorted(%w[01-a.md 1-a.md])
    second_pass = sorted(%w[01-a.md 1-a.md])
    assert_equal first_pass, second_pass
    assert_equal %w[01-a.md 1-a.md].sort, first_pass.sort
  end

  def test_pure_alphabetical_names_sort_alphabetically_case_insensitively
    assert_equal %w[apple.md Banana.md cherry.md], sorted(%w[Banana.md cherry.md apple.md])
  end

  def test_mixed_prefixed_and_unprefixed_names_put_digit_runs_first
    names = %w[appendix.md 01-intro.md 02-idea.md]
    assert_equal %w[01-intro.md 02-idea.md appendix.md], sorted(names)
  end
end
