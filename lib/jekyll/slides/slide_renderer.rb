# frozen_string_literal: true

module Jekyll
  module Slides
    class SlideRenderer
      def initialize(warning: nil, component_renderer: nil, options: {})
        @warning = warning
        @component_renderer = component_renderer || ComponentRenderer.new(warning: warning, options: options)
      end

      def render(markdown)
        PresentationParser.new(markdown).parse.each_with_index.map do |source, index|
          metadata = SlideMetadata.new(source, index: index, warning: @warning)
          rendered = @component_renderer.render_document(
            metadata.content,
            id_prefix: "slide-#{index + 1}-"
          )
          metadata.parse(components: rendered.components)
          fragments = rendered.fragments
          body = composition(metadata.layout, fragments)
          classes = ["slide", "layout-#{metadata.layout}", "bg-#{metadata.background}"]
          classes.concat(metadata.custom_class.split(/\s+/)) unless metadata.custom_class.empty?
          attrs = %(class="#{Support.escape(classes.join(' '))}" id="slide-#{index + 1}" data-slide="#{index + 1}" aria-label="Slide #{index + 1}")
          %(<section #{attrs}><div class="slide-content">#{body}</div></section>)
        end.join
      end

      private

      def composition(layout, fragments)
        prose = fragments.select { |kind, _html, _metadata| kind == :prose }.map { |_kind, html, _metadata| html }.join
        visual = fragments.select { |kind, _html, _metadata| kind == :visual }.map { |_kind, html, _metadata| html }.join
        case layout
        when "split-code"
          split_panes(fragments)
        when "code-result"
          %(<div class="prose">#{prose}</div><div class="stack">#{visual}</div>)
        when "code-left"
          %(<div class="panes"><div class="pane visual">#{visual}</div><div class="pane prose">#{prose}</div></div>)
        when "code-right"
          %(<div class="panes"><div class="pane prose">#{prose}</div><div class="pane visual">#{visual}</div></div>)
        when "code"
          code_layout(prose, visual)
        else
          fragments.map { |_kind, html, _metadata| html }.then { |body| %(<div class="prose">#{body.join}</div>) }
        end
      end

      def code_layout(prose, visual)
        prose_html = prose.empty? ? "" : %(<div class="prose">#{prose}</div>)
        %(#{prose_html}<div class="visual">#{visual}</div>)
      end

      def split_panes(fragments)
        visual_index = fragments.index { |kind, _| kind == :visual }
        return %(<div class="prose">#{fragments.map { |_kind, html, _metadata| html }.join}</div>) unless visual_index

        panes = []
        leading = fragments[0...visual_index]
        h1_intro = leading.length == 1 && leading.first[2][:heading_level] == 1
        global = if h1_intro
                   leading.map { |_kind, html, _metadata| html }.join
                 elsif leading.length > 1
                   leading[0...-1].map { |_kind, html, _metadata| html }.join
                 end
        pending = if h1_intro
                    +""
                  elsif leading.length > 1
                    leading.last[1].dup
                  else
                    leading.map { |_kind, html, _metadata| html }.join
                  end
        fragments[visual_index..].each do |kind, html, _metadata|
          if kind == :visual
            panes << %(<div class="pane">#{pending}#{html}</div>)
            pending = +""
          else
            pending << html
          end
        end
        if pending.empty?
          # no trailing prose
        elsif panes.empty?
          panes << %(<div class="pane">#{pending}</div>)
        else
          panes[-1] = panes[-1].sub(%r{</div>\z}, "#{pending}</div>")
        end
        prefix = global && !global.empty? ? %(<div class="prose">#{global}</div>) : ""
        panes.empty? ? prefix : %(#{prefix}<div class="panes">#{panes.join}</div>)
      end
    end
  end
end
