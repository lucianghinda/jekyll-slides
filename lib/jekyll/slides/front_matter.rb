# frozen_string_literal: true

require "yaml"
require "date"

module Jekyll
  module Slides
    # Splits a leading YAML front matter block off a Markdown source string.
    module FrontMatter
      module_function

      # Returns [values, body]. +values+ is a Hash for a well-formed leading
      # +---+ block; otherwise +values+ is {} and +body+ is +source+ unchanged.
      def split(source)
        source = source.to_s
        return [{}, source] unless source.start_with?("---\n", "---\r\n")

        lines = source.lines
        closing = lines[1..]&.index { |line| line.chomp == "---" }
        return [{}, source] unless closing

        closing += 1
        values = parse(lines[1...closing].join)
        return [{}, source] unless values

        [values, lines[(closing + 1)..]&.join.to_s]
      end

      def parse(text)
        return {} if text.strip.empty?

        parsed = YAML.safe_load(text, permitted_classes: [Date, Time, DateTime])
        parsed.is_a?(Hash) ? parsed : nil
      rescue Psych::Exception
        nil
      end
    end
  end
end
