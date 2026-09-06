# frozen_string_literal: true

require "pathname"
require "set"

module Jekyll
  module Slides
    # Finds folder-deck entries across a site's pages and output-collection
    # documents, assembles each into one Markdown string via +Deck+, and
    # prunes the slide files it consumed so they never appear in the built
    # site. Runs once per site, inside the +:site, :post_read+ hook, before
    # Liquid rendering and before +JekyllIntegration.process+ computes
    # +slides_count+.
    module DeckAssembler
      class << self
        # Assembles every folder deck the site's pages and output-collection
        # documents opt into. Mutates +site.pages+, each collection's
        # +docs+, and +site.static_files+ in place to remove consumed slide
        # files.
        def assemble(site)
          published = published_paths(site)
          entry_candidates(site).each { |entry| assemble_entry(site, entry, published) }
        end

        private

        # Every source path Jekyll actually read. A file its exclude: config
        # drops, or one whose front matter sets published: false, is absent
        # here, and a deck must not absorb it. Snapshotted before any pruning,
        # since pruning removes the very items this is built from.
        def published_paths(site)
          items = site.pages + site.collections.values.flat_map(&:docs) + site.static_files
          items.to_set { |item| absolute_path(site, item) }
        end

        def entry_candidates(site)
          collection_documents = site.collections.values.flat_map(&:docs)
          site.pages + collection_documents
        end

        def assemble_entry(site, entry, published)
          return unless presentation_entry?(entry)

          slides_option = entry.data["slides"]
          return unless slides_option

          entry_path = absolute_path(site, entry)
          unless index_entry?(entry_path, markdown_extensions(site))
            warn_entry(site, entry_path, "the entry of a deck folder must be named index.<ext>; leaving as a single-file deck")
            return
          end

          finish_assembly(site, entry, entry_path, build_deck(site, entry, entry_path, published))
        end

        def finish_assembly(site, entry, entry_path, deck)
          return unless deck.deck?

          entry.content = deck.content
          # Pruning does not depend on anything being selected. Opting in
          # absorbs the whole folder, so a file left out of an explicit
          # running order is cut from the deck rather than published alone.
          prune(site, deck.consumed_paths)
          register_dependencies(site, entry_path, deck.slide_paths)
          log_deck(site, entry_path, deck.slide_paths) unless deck.slide_paths.empty?
        end

        def presentation_entry?(entry)
          entry.respond_to?(:data) && entry.data.is_a?(Hash) && entry.data["layout"].to_s == "presentation"
        end

        def markdown_extensions(site)
          site.config["markdown_ext"].to_s.split(",")
        end

        def index_entry?(path, extensions)
          basename = File.basename(path)
          extname = File.extname(basename)
          return false if extname.empty?

          base = basename.delete_suffix(extname)
          ext = extname.delete_prefix(".").downcase
          base.casecmp("index").zero? && extensions.any? { |candidate| candidate.to_s.downcase == ext }
        end

        def build_deck(site, entry, entry_path, published)
          Deck.new(
            directory: File.dirname(entry_path),
            entry_path: entry_path,
            entry_body: entry.content,
            slides: entry.data["slides"],
            markdown_extensions: markdown_extensions(site),
            warning: ->(message) { warn_entry(site, entry_path, message) },
            read_options: Jekyll::Utils.merged_file_read_opts(site, {}),
            published: ->(path) { published.include?(path) }
          )
        end

        # Removes every consumed slide file from site.pages, each
        # collection's docs, and site.static_files, matching on absolute
        # source path. A Markdown file with no front matter is read by
        # Jekyll as a StaticFile rather than a Page, so pruning static
        # files is required, not optional.
        def prune(site, paths)
          return if paths.empty?

          consumed = paths.map { |path| File.expand_path(path) }
          site.pages.reject! { |page| consumed.include?(absolute_path(site, page)) }
          site.collections.each_value do |collection|
            collection.docs.reject! { |doc| consumed.include?(absolute_path(site, doc)) }
          end
          site.static_files.reject! { |file| consumed.include?(absolute_path(site, file)) }
        end

        def register_dependencies(site, entry_path, slide_paths)
          return unless site.respond_to?(:regenerator) && site.regenerator.respond_to?(:add_dependency)

          slide_paths.each { |path| site.regenerator.add_dependency(entry_path, path) }
        end

        def log_deck(site, entry_path, slide_paths)
          basenames = slide_paths.map { |path| File.basename(path) }
          Jekyll.logger.info(
            "Jekyll Slides:",
            "#{relative_path(site, entry_path)}: #{slide_paths.length} slide files (#{basenames.join(', ')})"
          )
        end

        def warn_entry(site, entry_path, message)
          Jekyll.logger.warn("Jekyll Slides:", "#{relative_path(site, entry_path)}: #{message}")
        end

        # Jekyll::Page#path is relative to the source; Jekyll::Document#path
        # and Jekyll::StaticFile#path are already absolute. expand_path
        # handles all three, since it ignores the base for a path that is
        # already absolute.
        def absolute_path(site, item)
          File.expand_path(item.path.to_s, site.source)
        end

        def relative_path(site, path)
          Pathname.new(path).relative_path_from(Pathname.new(site.source)).to_s
        end
      end
    end
  end
end
