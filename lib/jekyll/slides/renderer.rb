# frozen_string_literal: true

module Jekyll
  module Slides
    class Renderer < Jekyll::Renderer
      def convert(content)
        # Liquid has already run by the time this fires (Jekyll::Renderer#run
        # converts before place_in_layouts), so this is the true slide
        # count, including slides a {% for %} loop generated.
        #
        # document.data alone is not enough: a Document reaches the layout
        # through a live DocumentDrop that reads document.data on every
        # access, so writing it here is enough. A Page reaches the layout
        # through a plain Hash snapshot that Jekyll::Renderer#assign_pages!
        # already built and stashed in payload["page"] before convert runs,
        # so a Page's layout would keep seeing the old, pre-Liquid count
        # unless payload["page"] itself is updated too.
        count = PresentationParser.new(content).parse.length
        document.data["slides_count"] = count
        payload["page"]["slides_count"] = count
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
