# frozen_string_literal: true

module Jekyll
  module Slides
    # Reads one Markdown file and returns its slide sources. The file's own
    # front matter (+layout+, +background+, +class+) becomes a default
    # metadata comment applied to every slide the file contains; a slide's
    # own comment wins key by key.
    class SlideFile
      def initialize(path, warning: nil, read_options: {})
        @path = path
        @warning = warning
        @read_options = read_options
      end

      def slides
        @slides ||= build_slides
      end

      private

      def build_slides
        file_values, body = FrontMatter.split(File.read(@path, **@read_options))
        defaults = file_defaults(file_values)
        slide_sources = PresentationParser.new(body).parse

        if slide_sources.empty?
          Support.warn(@warning, "#{@path} produced no slides; skipping")
          return []
        end

        slide_sources.map { |slide| apply_defaults(slide, defaults) }
      end

      def file_defaults(file_values)
        file_values.each_with_object({}) do |(key, value), defaults|
          if SlideMetadata::KEYS.include?(key)
            defaults[key] = value
          else
            Support.warn(@warning, "Unknown slide file key #{key.inspect}; ignoring")
          end
        end
      end

      def apply_defaults(slide, defaults)
        return slide if defaults.empty?

        body, own_values = SlideMetadata.split_comment(slide)
        merged = defaults.merge(own_values)
        lines = SlideMetadata::KEYS.filter_map { |key| "#{key}: #{merged[key]}" if merged.key?(key) }
        "<!--\n#{lines.join("\n")}\n-->\n#{body}"
      end
    end
  end
end
