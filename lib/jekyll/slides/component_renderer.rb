# frozen_string_literal: true

require "kramdown"
require "kramdown-parser-gfm"
require "set"

module Jekyll
  module Slides
    class ComponentRenderer
      FRAGMENT_PATTERN = /<!-- jekyll-slides:start:(\d+) -->(.*?)<!-- jekyll-slides:end:\1 -->/m
      RenderedDocument = Struct.new(:components, :fragments, keyword_init: true)
      SIZES = %w[sm md lg].freeze
      # Advisory only: available space depends on the slide layout and component size.
      LONG_CODE_LINE_THRESHOLD = 20

      def self.render(markdown, warning: nil, options: {})
        new(warning: warning, options: options).render(markdown)
      end

      def initialize(warning: nil, rouge_renderer: nil, options: {})
        @warning = warning
        @rouge_renderer = rouge_renderer || RougeRenderer.new(warning: warning)
        @options = options
      end

      def render(markdown)
        render_document(markdown).fragments.map { |_kind, html, _metadata| html }.join
      end

      def render_fragments(markdown, id_prefix: "")
        render_document(markdown, id_prefix: id_prefix).fragments
      end

      def render_document(markdown, id_prefix: "")
        document = Kramdown::Document.new(markdown.to_s, kramdown_options(id_prefix))
        descriptors = []
        components = []
        document.root.children = document.root.children.flat_map do |element|
          next element if element.type == :blank

          index = descriptors.length
          kind, rendered, component = render_element(element)
          components << component if component
          descriptors << [kind, heading_level(element)]
          [marker("start", index), rendered, marker("end", index)]
        end

        html, warnings = Kramdown::Converter::Html.convert(document.root, document.options)
        warnings.each { |message| Support.warn(@warning, message) }
        RenderedDocument.new(
          components: components,
          fragments: merge_prose_fragments(extract_fragments(html, descriptors))
        )
      end

      private

      def kramdown_options(id_prefix)
        @options.merge(
          "input" => @options.fetch("input", "GFM"),
          "auto_id_prefix" => id_prefix,
          "footnote_prefix" => "#{@options.fetch('footnote_prefix', '')}#{id_prefix}"
        )
      end

      def render_element(element)
        attributes = component_attributes(element)
        component = component_type(element, attributes)
        return [:prose, element, nil] unless component

        source_lines = element.value.to_s.lines.map do |line|
          [line.sub(/\r?\n\z/, ""), line[/\r?\n\z/].to_s]
        end
        language = element.options[:lang].to_s
        html = render_component(component, source_lines, language, attributes)
        [:visual, raw_element(html), component]
      end

      def component_attributes(element)
        ial = element.options[:ial] || {}
        attributes = ial.each_with_object({ classes: [] }) do |(key, value), result|
          if key.to_s == "class"
            result[:classes] = value.to_s.split
          elsif key.to_s == "id"
            result[:id] = value
          else
            result[key.to_s] = value
          end
        end
        attributes[:id] ||= element.attr["id"]
        attributes
      end

      def component_type(element, attributes)
        return unless element.type == :codeblock
        return :editor if attributes[:classes].include?("editor")

        :terminal if attributes[:classes].include?("terminal")
      end

      def heading_level(element)
        element.type == :header ? element.options[:level] : nil
      end

      def marker(position, index)
        raw_element("<!-- jekyll-slides:#{position}:#{index} -->")
      end

      def raw_element(html)
        Kramdown::Element.new(:raw, html, {}, category: :block, type: "html")
      end

      def extract_fragments(html, descriptors)
        matches = html.to_enum(:scan, FRAGMENT_PATTERN).map { Regexp.last_match }
        fragments = matches.map do |match|
          kind, level = descriptors.fetch(match[1].to_i)
          [kind, match[2].strip, { heading_level: level }]
        end
        append_converter_tail(fragments, html[matches.last&.end(0).to_i..].to_s)
      end

      def append_converter_tail(fragments, tail)
        tail = tail.strip
        return fragments if tail.empty?

        if fragments.last&.first == :prose
          fragments.last[1] << tail
        else
          fragments << [:prose, tail, { heading_level: nil }]
        end
        fragments
      end

      def merge_prose_fragments(fragments)
        fragments.each_with_object([]) do |fragment, merged|
          kind, html, metadata = fragment
          previous = merged.last
          if kind == :prose && previous&.first == :prose && metadata[:heading_level].nil?
            previous[1] << html
          else
            merged << fragment
          end
        end
      end

      def render_component(component, source_lines, language, attrs)
        if source_lines.length > LONG_CODE_LINE_THRESHOLD
          Support.warn(@warning, "#{component.to_s.capitalize} block has #{source_lines.length} lines and may require scrolling; " \
                                 "consider splitting it across slides, especially for print.")
        end

        if component == :editor
          render_editor(source_lines, language, attrs)
        elsif component == :terminal
          render_terminal(source_lines, attrs)
        else
          ""
        end
      end

      def render_editor(lines, language, attrs)
        size = normalize_size(attrs["size"])
        highlight = line_range(attrs["highlight"], max_line: lines.length)
        focus = line_range(attrs["focus"], max_line: lines.length)
        line_numbers = line_numbers?(attrs.fetch("line_numbers", "true"))
        classes = ["code-window", "size-#{size}"] + attrs[:classes].reject { |name| name == "editor" }
        classes << "has-focus" unless focus.empty?
        attributes = window_attributes(classes, attrs)
        header = window_header(language: language)
        caption = attrs["title"] ? %(<figcaption>#{Support.escape(attrs['title'])}</figcaption>) : ""
        source = lines.map { |line, newline| line + newline }.join
        highlighted = @rouge_renderer.render_lines(source, language)
        highlight = highlight.to_set
        focus = focus.to_set
        code = lines.each_with_index.map do |(_line, _newline), index|
          line_classes = ["line"]
          line_classes << "is-highlighted" if highlight.include?(index + 1)
          line_classes << "is-focused" if focus.include?(index + 1)
          line_attrs = { class: line_classes.join(" ") }
          line_attrs["data-line-number"] = index + 1 if line_numbers
          %(<span#{html_attributes(line_attrs)}>#{highlighted[index]}</span>)
        end.join
        %(<figure#{attributes}>#{caption}#{header}<pre><code>#{code}</code></pre></figure>)
      end

      def render_terminal(lines, attrs)
        size = normalize_size(attrs["size"])
        classes = ["terminal-window", "size-#{size}"] + attrs[:classes].reject { |name| name == "terminal" }
        figure_attrs = window_attributes(classes, attrs)
        caption = attrs["title"] ? %(<figcaption>#{Support.escape(attrs['title'])}</figcaption>) : ""
        body = lines.map do |line, newline|
          visible = Support.escape(line)
          if (prompt_match = line.match(/\A([$>❯]) /))
            prompt = Support.escape(prompt_match[1])
            rest = Support.escape(line[1..].to_s)
            visible = %(<span class="prompt">#{prompt}</span><span class="cmd">#{rest}</span>)
          end
          %(<span class="tline">#{visible}#{Support.escape(newline)}</span>)
        end.join
        %(<figure#{figure_attrs}>#{caption}#{window_header}<pre><code>#{body}</code></pre></figure>)
      end

      # The macOS-style title bar both window types share: traffic lights on
      # the left, and for editors the language on the right. The centered title
      # is the figure's own caption, which stays a direct child of the figure so
      # the markup remains a valid figure/figcaption pair.
      def window_header(language: nil)
        header = +'<header class="code-window-header"><span class="code-window-controls" aria-hidden="true"><i></i><i></i><i></i></span>'
        header << %(<span class="code-window-language">#{Support.escape(language)}</span>) if language
        header << "</header>"
      end

      def window_attributes(classes, attrs)
        html_attributes(
          "class" => classes.join(" "),
          "id" => attrs[:id],
          "data-code-theme" => component_theme(attrs["theme"])
        )
      end

      # A component may carry any deck theme, so one window can show a light
      # terminal inside a dark deck. Returns nil to inherit the deck theme.
      def component_theme(value)
        return nil if value.nil? || value.to_s.empty?
        return value.to_s if THEMES.include?(value.to_s)

        Support.warn(@warning, "Unsupported component theme #{value.inspect}; expected one of #{THEMES.join(', ')}; " \
                               "using the deck theme")
        nil
      end

      def line_range(value, max_line: nil)
        RangeParser.parse(value, warning: @warning, max_line: max_line)
      end

      def line_numbers?(value)
        case value.to_s.downcase
        when "true"
          true
        when "false"
          false
        else
          Support.warn(@warning, "Invalid line_numbers #{value.inspect}; falling back to true")
          true
        end
      end

      def normalize_size(value)
        return "md" if value.nil? || value.to_s.empty?
        return value.to_s if SIZES.include?(value.to_s)

        Support.warn(@warning, "Unsupported component size #{value.inspect}; falling back to md")
        "md"
      end

      def html_attributes(values)
        values.map do |key, value|
          next if value.nil?

          %( #{key}="#{Support.escape(value)}")
        end.compact.join
      end
    end
  end
end
