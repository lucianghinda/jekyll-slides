# frozen_string_literal: true

module Jekyll
  module Slides
    # Renders a Markdown deck into slide sections without the page layout.
    class Presentation
      # @param markdown [String] Markdown without page YAML front matter
      # @param warning [#call, nil] receives advisory rendering warnings
      # @param options [Hash] kramdown options
      def initialize(markdown, warning: nil, options: {})
        @markdown = markdown
        @renderer = SlideRenderer.new(warning: warning, options: options)
      end

      # @param markdown [String] optional replacement for the initial Markdown
      # @return [String] rendered slide section HTML
      def render(markdown = @markdown)
        @renderer.render(markdown)
      end
    end
  end
end
