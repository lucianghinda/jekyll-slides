#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

class LlmGenerator
  MAIN_DOCUMENT = File.join("doc", "Jekyll", "Slides.md")
  DOCUMENTATION_INDEX = /(?:^# Documentation[ \t]*\r?\n(?:[ \t]*\r?\n|-[ \t]+\[[^\n]*\]\([^\n]*\)[ \t]*\r?\n)*)+\z/

  def initialize(root: File.expand_path("..", __dir__), stdout: $stdout, stderr: $stderr)
    @root = root
    @stdout = stdout
    @stderr = stderr
  end

  def call
    unless File.file?(main_document)
      stderr.puts "Missing #{main_document}"
      return false
    end

    content = "#{File.read(main_document).rstrip}\n".sub(DOCUMENTATION_INDEX, "").rstrip
    content = [content, "# Documentation", documentation_links].join("\n\n").rstrip << "\n"

    File.write(main_document, content)
    File.write(File.join(root, "llm.txt"), root_relative_links(content))
    stdout.puts "Updated #{main_document} (#{documentation_files.size} links)"
    true
  end

  private

  attr_reader :root, :stdout, :stderr

  def main_document
    File.join(root, MAIN_DOCUMENT)
  end

  def documentation_files
    Dir.glob(File.join(root, "doc", "Jekyll", "Slides", "**", "*.md"))
  end

  def documentation_links
    documentation_files.map do |path|
      relative_path = path.delete_prefix("#{File.dirname(main_document)}/")
      "- [#{relative_path}](#{relative_path})"
    end.join("\n")
  end

  def root_relative_links(content)
    # Leave fenced and inline code examples untouched when rebasing YARD links.
    content.split(/(```.*?```|~~~.*?~~~|`[^`\n]*`)/m).each_with_index.map do |part, index|
      next part if index.odd?

      part.gsub(/(?<!!)\[([^\]\n]+)\]\(([^)\s]+)\)/) do |link|
        label = Regexp.last_match(1)
        target = Regexp.last_match(2)
        next link if target.match?(%r{\A(?:[a-z][a-z\d+.-]*:|/|#)}i)

        path, suffix = target.split(/(?=[?#])/, 2)
        next link unless path.end_with?(".md")

        relative_path = Pathname.new(File.join(File.dirname(MAIN_DOCUMENT), path)).cleanpath
        "[#{label}](#{relative_path}#{suffix})"
      end
    end.join
  end
end

exit(LlmGenerator.new.call ? 0 : 1) if $PROGRAM_NAME == __FILE__
