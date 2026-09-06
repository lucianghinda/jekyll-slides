# frozen_string_literal: true

require "cgi/escape"
require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../lib/jekyll-slides"

class Minitest::Test
  def converter
    ->(markdown) { "<p>#{CGI.escapeHTML(markdown.strip)}</p>" }
  end

  # Captures Jekyll.logger.warn messages raised while +block+ runs, instead
  # of letting them reach stderr. Returns the messages as "topic message"
  # strings.
  def capture_warnings
    messages = []
    logger = Jekyll.logger
    original = logger.method(:warn)
    logger.define_singleton_method(:warn) { |topic, message = nil| messages << [topic, message].compact.join(" ") }
    yield
    messages
  ensure
    logger.define_singleton_method(:warn, original)
  end

  # Writes +files+ (a Hash of source-relative path => contents) into a
  # temporary Jekyll source directory, runs a real Jekyll::Site#process,
  # and yields the destination directory.
  def build_site(files)
    Dir.mktmpdir("jekyll-slides-build") do |root|
      source = File.join(root, "source")
      destination = File.join(root, "destination")
      FileUtils.mkdir_p(source)
      files.each do |path, contents|
        full_path = File.join(source, path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, contents)
      end
      File.write(File.join(source, "_config.yml"), "markdown: kramdown\n") unless files.key?("_config.yml")

      config = Jekyll.configuration(
        "source" => source,
        "destination" => destination,
        "quiet" => true,
        "disable_disk_cache" => true
      )
      Jekyll::Site.new(config).process
      yield destination
    end
  end

  def visible_code(html)
    CGI.unescapeHTML(html[%r{<pre><code>(.*?)</code></pre>}m, 1].to_s.gsub(/<[^>]+>/, ""))
  end
end
