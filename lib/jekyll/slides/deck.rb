# frozen_string_literal: true

module Jekyll
  module Slides
    # Represents one folder deck: an entry file plus the slide files a
    # directory holds. Reads slide files from disk and assembles them, with
    # the entry body, into one Markdown string ready for the existing
    # +PresentationParser+ pipeline. Knows nothing about Jekyll page objects.
    class Deck
      # Top-level presentation options an author might mistakenly nest under
      # +slides:+ instead of setting directly in front matter.
      OPTION_KEYS = %w[theme progress slide_numbers overview fullscreen aspect_ratio].freeze

      # rubocop:disable Metrics/ParameterLists -- this exact keyword set is the deck's public
      # construction contract; the Jekyll integration layer wires it verbatim.
      def initialize(directory:, entry_path:, entry_body:, slides:, markdown_extensions:, warning: nil, read_options: {}, published: nil)
        @directory = directory
        @entry_path = File.expand_path(entry_path)
        @entry_body = entry_body.to_s
        @slides_option = slides
        @markdown_extensions = Array(markdown_extensions).map { |ext| ext.to_s.downcase }
        @warning = warning
        @read_options = read_options
        @published = published
        @deck = resolve_deck?
      end
      # rubocop:enable Metrics/ParameterLists

      def deck?
        @deck
      end

      # The ordered slide file paths that make up +content+: the explicit
      # list in list order when +slides:+ names one, otherwise every
      # discovered file in natural order.
      def slide_paths
        @slide_paths ||= deck? ? resolve_slide_paths : []
      end

      # Every slide file the deck folder absorbs, so none is published on
      # its own: every discovered direct child, plus any explicitly listed
      # path (which may live in a subfolder). Order is not meaningful; this
      # is a set for pruning, not the render order. Identical to
      # +slide_paths+ when +slides:+ is +true+.
      def consumed_paths
        @consumed_paths ||= deck? ? resolve_consumed_paths : []
      end

      def content
        parts = []
        parts << @entry_body unless blank?(@entry_body)
        parts.concat(slide_files.flat_map(&:slides))
        parts.join("\n\n---\n\n")
      end

      private

      def blank?(text)
        text.to_s.strip.empty?
      end

      def slide_files
        @slide_files ||= slide_paths.map { |path| SlideFile.new(path, warning: @warning, read_options: @read_options) }
      end

      def resolve_deck?
        case @slides_option
        when true, Array
          true
        when false, nil
          false
        when Hash
          Support.warn(@warning, "Invalid slides value #{@slides_option.inspect}; set the top-level slides options " \
                                 "(#{OPTION_KEYS.join(', ')}) directly instead of nesting them under slides:; " \
                                 "treating as a single-file deck")
          false
        else
          Support.warn(@warning, "Invalid slides value #{@slides_option.inspect}; expected true, false, or a list of " \
                                 "file names; treating as a single-file deck")
          false
        end
      end

      def resolve_slide_paths
        @slides_option == true ? discover_slide_paths : explicit_slide_paths
      end

      def resolve_consumed_paths
        paths = discover_slide_paths
        @slides_option.is_a?(Array) ? paths | explicit_slide_paths : paths
      end

      def discover_slide_paths
        paths = Dir.children(@directory).each_with_object([]) do |basename, found|
          next if basename.start_with?("_", ".")

          path = File.join(@directory, basename)
          next unless File.file?(path)
          next unless markdown_extension?(basename)
          next if File.expand_path(path) == @entry_path
          next unless published?(path)

          found << path
        end
        paths.sort_by { |path| Support.natural_sort_key(File.basename(path)) }
      end

      def markdown_extension?(basename)
        @markdown_extensions.include?(File.extname(basename).delete_prefix(".").downcase)
      end

      # Memoized because both the rendering set and the pruning set ask for
      # it, and resolve warns about missing or out-of-bounds names.
      def explicit_slide_paths
        @explicit_slide_paths ||= @slides_option.filter_map { |name| resolve(name) }
      end

      def resolve(name)
        root = File.expand_path(@directory) + File::SEPARATOR
        path = File.expand_path(File.join(@directory, name.to_s))
        unless path.start_with?(root)
          Support.warn(@warning, "Slide file #{name.inspect} escapes the deck directory; ignoring")
          return nil
        end
        if path == @entry_path
          Support.warn(@warning, "Slide file #{name.inspect} is the deck entry itself; ignoring")
          return nil
        end
        unless File.file?(path)
          Support.warn(@warning, "Slide file #{name.inspect} does not exist; ignoring")
          return nil
        end
        unless published?(path)
          Support.warn(@warning, "Slide file #{name.inspect} is excluded or not published; ignoring")
          return nil
        end
        path
      end

      # Discovery reads the folder straight from disk, which bypasses the
      # filtering Jekyll already applied: files its exclude: config drops and
      # files whose front matter sets published: false are never read. Absorbing
      # one would publish content the author withheld, inside the deck.
      def published?(path)
        return true unless @published

        @published.call(File.expand_path(path))
      end
    end
  end
end
