# frozen_string_literal: true

require "yaml"
require "date"

module Jekyll
  module Slides
    class PresentationParser
      def self.parse(body)
        new(body).parse
      end

      def initialize(body = nil)
        @body = body.to_s
      end

      def parse(body = @body)
        @invalid_front_matter = false
        @invalid_front_matter_closing = nil
        @unterminated_front_matter = false
        source = strip_front_matter(body.to_s)
        slides = []
        current = []
        fence = nil

        source.each_line.with_index do |line, line_index|
          if fence
            fence = nil if closing_fence?(line, fence)
            current << line
          elsif (opening = fence_line(line))
            fence = opening
            current << line
          elsif slide_separator?(line, line_index)
            slide = normalize_slide(current.join)
            slides << slide if slide
            current = []
          else
            current << line
          end
        end
        slide = normalize_slide(current.join)
        slides << slide if slide
        slides
      end

      private

      def slide_separator?(line, line_index)
        return false unless line.chomp == "---"
        return false if @unterminated_front_matter && line_index.zero?
        return false if @invalid_front_matter && [0, @invalid_front_matter_closing].include?(line_index)

        true
      end

      def strip_front_matter(source)
        return source unless source.start_with?("---\n", "---\r\n")

        lines = source.lines
        closing = lines[1..]&.index { |line| line.chomp == "---" }
        unless closing
          @unterminated_front_matter = true
          return source
        end
        closing += 1

        front_lines = lines[1...closing]
        valid = begin
          parsed = YAML.safe_load(front_lines.join, permitted_classes: [Date, Time, DateTime])
          front_lines.empty? || parsed.is_a?(Hash)
        rescue Psych::Exception
          false
        end
        unless valid
          @invalid_front_matter = true
          @invalid_front_matter_closing = closing
          return source
        end
        lines[(closing + 1)..]&.join.to_s
      end

      def normalize_slide(text)
        return if text.strip.empty?

        text = text.sub(/\A(?:[ \t]*\r?\n)+/, "")
        text.sub(/(?:\r?\n[ \t]*)+\z/, "")
      end

      def fence_line(line)
        match = line.match(/\A( {0,3})(`{3,}|~{3,})([^\r\n]*)\r?\n?\z/)
        return unless match
        return if match[2].start_with?("`") && match[3].include?("`")

        { indent: match[1].length, char: match[2][0], length: match[2].length }
      end

      def closing_fence?(line, fence)
        line.match?(/\A {0,3}#{Regexp.escape(fence[:char])}{#{fence[:length]},} *\r?\n?\z/)
      end
    end
  end
end
