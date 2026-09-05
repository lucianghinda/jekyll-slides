# frozen_string_literal: true

module Jekyll
  module Slides
    class SlideMetadata
      LAYOUTS = %w[title statement content code code-left code-right split-code code-result].freeze
      BACKGROUNDS = %w[plain gradient grid spotlight].freeze
      KEYS = %w[layout class background].freeze

      attr_reader :layout, :background, :custom_class, :content, :values

      def self.parse(content, index: 0, warning: nil, components: nil)
        new(content, index: index, warning: warning).parse(components: components)
      end

      def initialize(content, index: 0, warning: nil)
        @original_content = content.to_s
        @index = index
        @warning = warning
        @content, @values = extract_comment(@original_content)
        @background = @values["background"] || "plain"
        @custom_class = @values["class"].to_s.strip
      end

      def parse(components: nil)
        components ||= ComponentRenderer.new(warning: @warning).render_document(@content).components
        @layout = @values["layout"] || inferred_layout(components)

        unless LAYOUTS.include?(@layout)
          Support.warn(@warning, "Invalid slide layout #{@layout.inspect}; falling back to automatic layout")
          @layout = inferred_layout(components)
        end
        unless BACKGROUNDS.include?(@background)
          Support.warn(@warning, "Invalid slide background #{@background.inspect}; falling back to plain")
          @background = "plain"
        end
        self
      end

      private

      def extract_comment(body)
        match = body.match(/\A[ \t]*(<!--(.*?)-->)[ \t]*(?:\r?\n)?/m)
        return [body, {}] unless match

        values = {}
        lines = match[2].to_s.lines.map(&:strip).reject(&:empty?)
        parsed = lines.map { |line| line.match(/\A(\w[\w-]*)\s*:\s*(.*?)\z/) }
        return [body, {}] unless parsed.all?
        return [body, {}] unless parsed.any? { |match_data| KEYS.include?(match_data[1]) }

        parsed.each do |match_data|
          key = match_data[1]
          if KEYS.include?(key)
            values[key] = match_data[2].strip
          else
            Support.warn(@warning, "Unknown slide metadata key #{key.inspect}; ignoring")
          end
        end
        [body[match.end(0)..].to_s, values]
      end

      def inferred_layout(components)
        return "code-result" if components == %i[editor terminal]

        editors = components.count(:editor)
        terminals = components.count(:terminal)
        return "split-code" if editors > 1 && components.all? { |component| component == :editor }
        return "code" if editors.positive? || terminals.positive?
        return "title" if @index.to_i.zero?

        statement_content?(@content) ? "statement" : "content"
      end

      def statement_content?(body)
        chunks = body.strip.split(/\n\s*\n/)
        return false unless (1..2).cover?(chunks.length)
        return false unless chunks.first.match?(/\A\s*\#{1,6}\s+.+\z/m)
        return true if chunks.length == 1

        chunks.last.lines.none? { |line| line.match?(/\A\s*(?:[#>*-]|```|~~~)/) }
      end
    end
  end
end
