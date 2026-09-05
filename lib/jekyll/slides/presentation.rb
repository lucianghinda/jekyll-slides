# frozen_string_literal: true

module Jekyll
  module Slides
    class Presentation
      def initialize(markdown, warning: nil, options: {})
        @markdown = markdown
        @renderer = SlideRenderer.new(warning: warning, options: options)
      end

      def render(markdown = @markdown)
        @renderer.render(markdown)
      end
    end
  end
end
