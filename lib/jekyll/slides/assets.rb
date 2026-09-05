# frozen_string_literal: true

module Jekyll
  module Slides
    module Assets
      class SiteAssetFile < Jekyll::StaticFile
        def write(dest)
          return false if site_item_claims_destination?(dest)

          super
        end

        private

        def site_item_claims_destination?(dest)
          site_items.any? do |item|
            item.write? && item.destination(dest) == destination(dest)
          end
        end

        def site_items
          @site.pages + @site.documents
        end
      end

      module_function

      def install(site)
        asset_files.each do |path|
          relative_path = path.delete_prefix("#{ROOT}/")
          next if site.static_files.any? { |file| file.relative_path.delete_prefix("/") == relative_path }

          site.static_files << SiteAssetFile.new(
            site,
            ROOT,
            File.dirname(relative_path),
            File.basename(relative_path)
          )
        end
      end

      def asset_files
        Dir[File.join(ROOT, "assets", "**", "*")].select { |path| File.file?(path) }.sort
      end
    end
  end
end
