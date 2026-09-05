# frozen_string_literal: true

require_relative "lib/jekyll/slides/version"

Gem::Specification.new do |spec|
  spec.name = "jekyll-slides"
  spec.version = Jekyll::Slides::VERSION
  spec.authors = ["Lucian Ghinda"]
  spec.summary = "Polished technical presentations from Markdown for Jekyll"
  spec.description = "A Jekyll plugin for turning Markdown into accessible, " \
                     "responsive slide presentations with code and terminal components."
  spec.homepage = "https://github.com/lucianghinda/jekyll-slides"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1"
  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "#{spec.homepage}/tree/main",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "_includes/**/*",
      "_layouts/**/*",
      "assets/**/*",
      "lib/**/*.rb",
      "LICENSE.txt",
      "CHANGELOG.md",
      "README.md"
    ].select { |path| File.file?(path) }.sort
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", ">= 4.3", "< 5"
  spec.add_dependency "kramdown", ">= 2.4", "< 3"
  spec.add_dependency "kramdown-parser-gfm", ">= 1.1", "< 2"
  spec.add_dependency "rouge", ">= 4", "< 5"
end
