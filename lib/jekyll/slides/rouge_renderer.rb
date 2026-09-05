# frozen_string_literal: true

module Jekyll
  module Slides
    class RougeRenderer
      def initialize(warning: nil)
        @warning = warning
      end

      def render(source, language)
        lexer = Rouge::Lexer.find(language.to_s)
        return Support.escape(source.to_s) unless lexer

        Rouge::Formatters::HTML.new.format(lexer.lex(source.to_s))
      rescue StandardError => e
        Support.warn(@warning, "Unable to highlight #{language.inspect}: #{e.message}")
        Support.escape(source.to_s)
      end

      def render_lines(source, language)
        source = source.to_s
        distribute(render(source, language), source)
      end

      private

      def distribute(html, source)
        lines = []
        current = +""
        open_tags = []
        html.scan(/<[^>]+>|[^<]+/m).each do |token|
          if token.start_with?("<")
            current << token
            if token.match?(/\A<span\b/)
              open_tags << token
            elsif token == "</span>"
              open_tags.pop
            end
            next
          end

          token.split(/(\r?\n)/, -1).each do |part|
            if part.match?(/\A\r?\n\z/)
              current << ("</span>" * open_tags.length) << part
              lines << current
              current = +open_tags.join
            else
              current << part
            end
          end
        end
        lines << current unless current.empty?
        expected = source.lines.length
        lines.first(expected)
      end
    end
  end
end
