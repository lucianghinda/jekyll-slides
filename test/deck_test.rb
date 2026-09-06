# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class DeckTest < Minitest::Test
  MARKDOWN_EXTENSIONS = %w[md markdown].freeze

  def write(dir, relative_path, content)
    path = File.join(dir, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  def deck(dir, entry_path:, slides:, **options)
    warnings = options[:warnings] || []
    Jekyll::Slides::Deck.new(
      directory: dir,
      entry_path: entry_path,
      entry_body: options.fetch(:entry_body, ""),
      slides: slides,
      markdown_extensions: MARKDOWN_EXTENSIONS,
      warning: ->(message) { warnings << message },
      published: options[:published]
    )
  end

  def test_true_opts_in_and_discovers_slides_in_natural_order
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "02-idea.md", "# Idea")
      write(dir, "10-end.md", "# End")
      write(dir, "01-intro.md", "# Intro")

      built = deck(dir, entry_path: entry, slides: true)
      assert_predicate built, :deck?
      assert_equal %w[01-intro.md 02-idea.md 10-end.md].map { |name| File.join(dir, name) }, built.slide_paths
    end
  end

  def test_discovery_excludes_entry_underscore_dot_subfolders_and_non_markdown
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-slide.md", "# Slide")
      write(dir, "_draft.md", "# Draft")
      write(dir, ".hidden.md", "# Hidden")
      write(dir, "diagram.png", "not markdown")
      write(dir, "sub/02-nested.md", "# Nested")

      built = deck(dir, entry_path: entry, slides: true)
      assert_equal [File.join(dir, "01-slide.md")], built.slide_paths
    end
  end

  def test_explicit_array_selects_and_orders_a_subset
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")
      write(dir, "02-idea.md", "# Idea")
      write(dir, "03-code.md", "# Code")

      built = deck(dir, entry_path: entry, slides: %w[03-code.md 01-intro.md])
      assert_equal [File.join(dir, "03-code.md"), File.join(dir, "01-intro.md")], built.slide_paths
    end
  end

  def test_missing_named_file_warns_and_is_skipped
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")
      warnings = []

      built = deck(dir, entry_path: entry, slides: %w[01-intro.md missing.md], warnings: warnings)
      assert_equal [File.join(dir, "01-intro.md")], built.slide_paths
      assert_equal 1, warnings.length
      assert_includes warnings.first, "missing.md"
    end
  end

  def test_path_escaping_the_deck_directory_is_rejected_with_a_warning
    Dir.mktmpdir do |dir|
      entry = write(dir, "talk/index.md", "")
      write(dir, "talk/01-intro.md", "# Intro")
      write(dir, "outside.md", "# Outside")
      warnings = []

      built = deck(File.join(dir, "talk"), entry_path: entry, slides: %w[01-intro.md ../outside.md], warnings: warnings)
      assert_equal [File.join(dir, "talk", "01-intro.md")], built.slide_paths
      assert_equal 1, warnings.length
      assert_includes warnings.first, "../outside.md"
    end
  end

  def test_hash_slides_value_warns_and_does_not_opt_in
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")
      warnings = []

      built = deck(dir, entry_path: entry, slides: { "theme" => "midnight" }, warnings: warnings)
      refute_predicate built, :deck?
      assert_empty built.slide_paths
      assert_equal 1, warnings.length
      assert_includes warnings.first, "theme"
    end
  end

  def test_false_and_nil_do_not_opt_in_without_warning
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")

      [false, nil].each do |value|
        warnings = []
        built = deck(dir, entry_path: entry, slides: value, warnings: warnings)
        refute_predicate built, :deck?
        assert_empty built.slide_paths
        assert_empty warnings
      end
    end
  end

  def test_content_joins_entry_body_and_slide_sources_with_the_separator
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")
      write(dir, "02-idea.md", "# Idea")

      built = deck(dir, entry_path: entry, entry_body: "# Welcome", slides: true)
      assert_equal "# Welcome\n\n---\n\n# Intro\n\n---\n\n# Idea", built.content
    end
  end

  def test_blank_entry_body_is_not_prepended
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")

      built = deck(dir, entry_path: entry, entry_body: "   \n", slides: true)
      assert_equal "# Intro", built.content
    end
  end

  def test_a_slide_file_with_several_slides_contributes_each_source
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-many.md", "# First\n\n---\n\n# Second")

      built = deck(dir, entry_path: entry, slides: true)
      assert_equal "# First\n\n---\n\n# Second", built.content
    end
  end

  def test_consumed_paths_matches_slide_paths_when_slides_is_true
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "02-idea.md", "# Idea")
      write(dir, "01-intro.md", "# Intro")

      built = deck(dir, entry_path: entry, slides: true)
      assert_equal built.slide_paths, built.consumed_paths
    end
  end

  def test_consumed_paths_is_empty_when_not_a_deck
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")

      built = deck(dir, entry_path: entry, slides: false)
      assert_empty built.consumed_paths
    end
  end

  def test_consumed_paths_absorbs_the_whole_folder_even_with_an_explicit_list
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")
      write(dir, "02-idea.md", "# Idea")
      write(dir, "03-cut.md", "# Cut")

      built = deck(dir, entry_path: entry, slides: %w[02-idea.md 01-intro.md])
      assert_equal [File.join(dir, "02-idea.md"), File.join(dir, "01-intro.md")], built.slide_paths
      assert_equal(
        [File.join(dir, "01-intro.md"), File.join(dir, "02-idea.md"), File.join(dir, "03-cut.md")].sort,
        built.consumed_paths.sort
      )
    end
  end

  def test_consumed_paths_includes_an_explicitly_listed_subfolder_file
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")
      write(dir, "shared/02-idea.md", "# Idea")

      built = deck(dir, entry_path: entry, slides: %w[01-intro.md shared/02-idea.md])
      assert_includes built.consumed_paths, File.join(dir, "shared", "02-idea.md")
    end
  end

  def test_an_explicit_list_naming_the_entry_ignores_it_and_warns
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")
      warnings = []

      built = deck(dir, entry_path: entry, slides: %w[index.md 01-intro.md], warnings: warnings)

      assert_equal [File.join(dir, "01-intro.md")], built.slide_paths
      refute_includes built.consumed_paths, entry
      assert_equal 1, warnings.length
      assert_includes warnings.first, "deck entry itself"
    end
  end

  def test_discovery_skips_a_path_the_site_withheld
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")
      withheld = write(dir, "02-draft.md", "# Draft")

      built = deck(dir, entry_path: entry, slides: true, published: ->(path) { path != withheld })

      assert_equal [File.join(dir, "01-intro.md")], built.slide_paths
      refute_includes built.consumed_paths, withheld
    end
  end

  def test_an_explicitly_listed_withheld_path_warns_and_is_skipped
    Dir.mktmpdir do |dir|
      entry = write(dir, "index.md", "")
      write(dir, "01-intro.md", "# Intro")
      withheld = write(dir, "02-draft.md", "# Draft")
      warnings = []

      built = deck(
        dir,
        entry_path: entry,
        slides: %w[01-intro.md 02-draft.md],
        warnings: warnings,
        published: ->(path) { path != withheld }
      )

      assert_equal [File.join(dir, "01-intro.md")], built.slide_paths
      refute_includes built.consumed_paths, withheld
      assert_equal 1, warnings.length
      assert_includes warnings.first, "excluded or not published"
    end
  end
end
