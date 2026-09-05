# frozen_string_literal: true

module Jekyll
  module Slides
    class Renderer < Jekyll::Renderer
      def convert(content)
        Presentation.new(
          content,
          warning: method(:warning),
          options: site.config.fetch("kramdown", {})
        ).render
      end

      private

      def warning(message)
        Jekyll.logger.warn("Jekyll Slides:", "#{document.relative_path}: #{message}")
      end
    end
  end
end
