# frozen_string_literal: true

module Jekyll
  module Slides
    class RangeParser
      # Prevent author-controlled ranges from forcing unbounded allocation.
      MAX_RANGE_SIZE = 100_000

      class << self
        def parse(value, warning: nil, max_line: nil)
          new(value, warning: warning, max_line: max_line).parse
        end
      end

      def initialize(value = nil, warning: nil, max_line: nil)
        @value = value
        @warning = warning
        @max_line = max_line
      end

      def parse
        return [] if @value.nil? || @value.to_s.strip.empty?

        spans = @value.to_s.split(",", -1).map do |token|
          token = token.strip
          case token
          when /\A([1-9]\d*)\z/
            number = Regexp.last_match(1).to_i
            raise ArgumentError if @max_line && number > @max_line

            [number, number]
          when /\A([1-9]\d*)-([1-9]\d*)\z/
            first = Regexp.last_match(1).to_i
            last = Regexp.last_match(2).to_i
            raise ArgumentError if first > last || last - first + 1 > MAX_RANGE_SIZE
            raise ArgumentError if @max_line && last > @max_line

            [first, last]
          else
            raise ArgumentError
          end
        end
        raise ArgumentError if spans.sum { |first, last| last - first + 1 } > MAX_RANGE_SIZE

        spans.flat_map { |first, last| (first..last).to_a }.uniq.sort
      rescue ArgumentError
        Support.warn(@warning, "Invalid line range #{@value.inspect}; ignoring range")
        []
      end
    end
  end
end
