# Folder decks: one file per slide

> **For agentic workers:** implement this plan task by task. Each numbered section is one delegated unit of work. Do not start a section until its dependencies are checked off.

**Goal:** Author a presentation as a folder of Markdown files, one file per slide, ordered by a numeric filename prefix and alphabetically otherwise. Keep the existing single-file deck working unchanged, and keep a file free to hold more than one slide.

**Architecture:** A folder deck is assembled into the same Markdown string the current parser already consumes, before Liquid runs. Nothing downstream of `document.content` changes: Liquid, `PresentationParser`, `SlideMetadata`, `ComponentRenderer`, `SlideRenderer`, and the `presentation` layout are untouched. The new code is a read-and-assemble step inside the existing `:site, :post_read` hook.

**Tech stack:** Ruby/Jekyll, kramdown/Rouge, Minitest. No new runtime or development dependencies.

**Ruby activation** (chruby, required before any `ruby`/`bundle`/`rake`):

```sh
source /opt/homebrew/share/chruby/chruby.sh && chruby ruby-4.0.1
```

## Authoring contract

```
talks/my-talk/
  index.md          # deck front matter, opts in with `slides: true`
  01-title.md
  02-the-idea.md
  03-code.md
  diagram.png       # ordinary static file, untouched
```

```yaml
# talks/my-talk/index.md
---
layout: presentation
title: My talk
slides: true
---
```

- **Entry file.** A deck folder is a folder containing `index.<markdown_ext>` whose resolved layout is `presentation`. The folder is the deck; the entry supplies front matter and the deck URL.
- **Opt in.** The entry declares `slides:`. `true` discovers slide files; an array names them explicitly and in order; `false` or absent means an ordinary single-file deck with siblings untouched.
- **Discovery.** Every other Markdown file that is a direct child of the folder, excluding names starting with `_` or `.`. Not recursive. An explicit `slides:` array may name paths in subfolders.
- **Order.** Natural sort of the filename: runs of digits compare numerically, everything else compares as lowercased text, digits before letters. `01-intro.md` precedes `02-idea.md` precedes `10-end.md` precedes `appendix.md`. Files with no numeric prefix therefore sort alphabetically among themselves.
- **Slide files.** Each file holds one slide, or several separated by `---` exactly as today. A file may carry YAML front matter with `layout`, `background`, and `class`; those apply to every slide in the file, and a slide's own HTML comment overrides them key by key.
- **Entry body.** If the entry file has body content it becomes the leading slides of the deck.
- **Output.** Opting in absorbs the whole folder. Every Markdown file the folder holds is removed from the site's pages, collection documents, and static files, so none of them is ever published on its own. An explicit `slides:` list controls order and inclusion in the rendered deck, not what gets absorbed: a slide commented out of the list is cut from the deck, not promoted to a standalone page.

## Decisions

- **Explicit `slides:` opt-in rather than automatic folder detection.** The README documents `defaults:` rules that apply `layout: presentation` to every page. Automatic detection would let such a rule turn any folder holding an `index.md` into a deck and silently swallow its sibling pages. The opt-in key makes absorption an author's decision. It costs one line in front matter the author is already writing.
- **Entry must be named `index`.** It makes the deck folder unambiguous and gives the deck a clean folder URL. A document that sets `slides:` while not being an index file gets a warning and is treated as a single-file deck.
- **Slide files are read from disk, not from Jekyll page objects.** A Markdown file without front matter never becomes a `Page`; it becomes a `StaticFile`. Reading from disk handles both uniformly and gives the author's real front matter, free of `defaults:` merging.
- **Assembly produces plain Markdown joined by `---`.** Slide sources come out of `PresentationParser`, so by construction none of them contains a bare `---` line outside a fence, and re-joining round-trips exactly. File-level front matter is injected as the existing HTML metadata comment so it survives Liquid without a fragile parallel array. A Liquid loop that emits `---` separators keeps working.
- **`PresentationParser` is not refactored.** Its front matter handling carries subtle invalid-front-matter semantics tied to separator line indices. A new small `FrontMatter` helper serves the new code instead. The duplication is a few lines and the risk saved is real.
- **The explicit list is an outline, not just an ordering escape hatch.** Writing a real deck showed the array form is the more useful one day to day: the entry file becomes a readable running order, and cutting a slide for time is commenting out one line. Filename ordering stays the zero-configuration default, and the README leads with the list for decks that get reordered.
- **`slides_count` is recomputed after Liquid.** The value assigned in `process` comes from the raw pre-Liquid source, so a deck that generates slides with a `{% for %}` loop reports too few. `Renderer#convert` runs after Liquid and already parses the final source, so it writes the true count back. The browser runtime prefers the live DOM count and only falls back to the attribute, so the stale value degraded the JavaScript-disabled path alone.
- **Rejected: slide files in a `_slides/` subfolder.** Jekyll ignores underscore-prefixed directories, so it would need no opt-in key and no pruning. It was rejected because it adds a directory level and does not match a deck folder holding its slides directly.

## 1. Foundation and deck assembly

Owner: one agent. Files: `lib/jekyll/slides/front_matter.rb`, `lib/jekyll/slides/slide_file.rb`, `lib/jekyll/slides/deck.rb`, `lib/jekyll/slides/support.rb`, `lib/jekyll/slides/slide_metadata.rb`, `lib/jekyll/slides.rb`, `test/front_matter_test.rb`, `test/slide_file_test.rb`, `test/deck_test.rb`, `test/support_test.rb`.

Depends on: nothing.

- [ ] Add `Jekyll::Slides::FrontMatter.split(source)` returning `[values, body]`. Values is a Hash for a well-formed leading `---` block, otherwise `{}` with the source returned unchanged. Accept CRLF. Use `YAML.safe_load` with `Date`, `Time`, and `DateTime` permitted, and rescue `Psych::Exception`.
- [ ] Add `Jekyll::Slides::Support.natural_sort_key(name)` returning a comparable array. Split the name into digit and non-digit runs; emit `[0, integer, ""]` for digits and `[1, 0, downcased_text]` for text; append `[2, 0, name]` as a stable tiebreaker so `1-a` and `01-a` order deterministically.
- [ ] Extract the metadata comment parser from `SlideMetadata#extract_comment` into `SlideMetadata.split_comment(body, warning: nil)` returning `[body_without_comment, values]`, and make the instance method call it. Preserve current behavior exactly: a comment whose lines are not all `key: value` is left in the body, a comment with no recognized key is left in the body, and unknown keys warn only when a warning receiver is given. Existing `test/slide_metadata_test.rb` must pass unchanged.
- [ ] Add `Jekyll::Slides::SlideFile`. Given a path and read options, read the file, split its front matter, split the body with `PresentationParser`, and return slide sources with the file's `layout`/`background`/`class` merged into each slide's metadata comment. A slide's own comment wins key by key. Warn for unknown front matter keys and for a file that yields no slides. Do not warn twice: pass no warning receiver into `split_comment`.
- [ ] Add `Jekyll::Slides::Deck`. Given a site and an entry document, expose the deck directory, the ordered slide file paths, and the assembled Markdown. Resolve `slides:` as `true` (discover), an Array (explicit, ordered), or anything else (warn and treat as no deck; a Hash gets a message pointing at the top-level option keys). Reject explicit paths that escape the deck directory. Warn for a named file that does not exist. Discovery uses `site.config["markdown_ext"]`, direct children only, excluding the entry and names starting with `_` or `.`. Read with `Jekyll::Utils.merged_file_read_opts(site, {})`.
- [ ] Assemble as the entry body, when not blank, followed by every slide source, joined with `\n\n---\n\n`.
- [ ] `require_relative` the three new files from `lib/jekyll/slides.rb` in dependency order.
- [ ] Unit tests: natural ordering including mixed prefixed and unprefixed names and two-digit versus one-digit prefixes; discovery excluding the entry, underscore and dot names, subfolders, and non-Markdown files; explicit list ordering, missing file warning, and path escape rejection; a multi-slide file; file front matter applied to every slide in a file; a slide comment overriding one key while inheriting another; a file with no front matter; an empty file; CRLF input.

## 2. Jekyll integration

Owner: one agent. Files: `lib/jekyll/slides/jekyll_integration.rb`, `test/jekyll_integration_test.rb`.

Depends on: section 1.

- [ ] In `process_site`, after `install_resources` and before processing documents, build decks from every page and output-collection document whose layout is `presentation` and whose `slides:` value opts in.
- [ ] Set the entry's `content` to the assembled Markdown. Leave `content` untouched for single-file decks so the current behavior is byte-identical.
- [ ] Add `Deck#consumed_paths`: every discovered Markdown child of the folder plus any explicitly listed path, without duplicates. It is the pruning set; `#slide_paths` stays the rendering set.
- [ ] Remove every consumed slide file from `site.pages`, from each `collection.docs`, and from `site.static_files`, matching on the absolute source path.
- [ ] Recompute `slides_count` in `Renderer#convert` from the parsed post-Liquid source, keeping the pre-Liquid assignment as the initial value.
- [ ] Warn when a non-index document sets `slides:`, and treat it as a single-file deck.
- [ ] Register each slide file as a regeneration dependency of the entry when `site.regenerator` responds to `add_dependency`, so `--incremental` rebuilds the deck when a slide file changes.
- [ ] Log one info line per deck naming the entry and the ordered slide files it absorbed.
- [ ] Compute `slides_count` after assembly. Confirm `presentation_documents` is evaluated after pruning.
- [ ] Real-build tests: a folder deck renders its slides in filename order with correct `data-slide` numbering; no slide file appears in the output as HTML or as a copied Markdown file; a slide file with no front matter is consumed rather than copied; Liquid inside a slide file is evaluated; `{% raw %}` in a slide file is preserved; a folder deck inside an output collection builds; slide file front matter sets layout and background; an entry body becomes the leading slides; `slides:` absent leaves sibling pages published; an explicit `slides:` array selects and orders a subset; a Hash `slides:` warns and leaves the deck single-file.
- [ ] All existing tests in the file must still pass, including the scoped-defaults test, which proves sibling pages are untouched without the opt-in.

## 3. Examples

Owner: one agent, parallel with section 4. Files: `examples/beautiful-ruby/`, `examples/readability.md`, `test/example_presentation_test.rb`.

Depends on: section 2.

- [ ] Convert `examples/beautiful-ruby.md` into `examples/beautiful-ruby/` with `index.md` carrying the existing front matter plus `slides: true`, and ten files named `01-…md` through `10-…md`, one slide each. Move each slide's HTML metadata comment into the file's YAML front matter to demonstrate the authoring style. Keep the rendered result identical.
- [ ] Leave `examples/readability.md` as a single-file deck, which is the backward-compatibility proof.
- [ ] Update `test/example_presentation_test.rb` so it still asserts ten sections and every existing layout, background, component, and highlighting assertion. Add assertions that the built site contains no `beautiful-ruby/01-*.html` and no copied `.md` slide files.
- [ ] Run the installed-gem example build and confirm it passes.

## 4. Documentation

Owner: one agent, parallel with section 3. Files: `README.md`, `CHANGELOG.md`, `docs/architecture-decisions.md`.

Depends on: section 2.

- [ ] README: add a "Deck folders" section after "Author a deck". Show the folder layout, the `slides: true` opt-in, the ordering rule, per-file front matter as the alternative to the HTML comment, multiple slides in one file, the explicit `slides:` array, and the fact that consumed files are not published. State plainly that files inside a deck folder are absorbed only when the entry opts in.
- [ ] CHANGELOG: one Unreleased entry for folder decks and one for slide file front matter.
- [ ] Architecture decisions: record that deck assembly happens in `:site, :post_read` before Liquid, that assembly emits Markdown rather than HTML so the rendering contract is unchanged, that absorption is opt-in because of `defaults:`, and that slide files are read from disk because a front-matter-less Markdown file is a static file.

## 5. Safari scale fix

Owner: one agent, parallel with sections 3 and 4. Files: `src/css/components/_base.css`, `src/css/components/_slides.css`, `assets/css/presentation.css`, `test/presentation_css_test.rb`, `CHANGELOG.md`.

Depends on: nothing.

Slide scale comes from the CSS length-division trick `tan(atan2(a, b))`, because CSS cannot divide a length by a length. Safari passes the `@supports` test for that syntax but computes it with the wrong sign, and a negative `scale()` is a 180 degree rotation, so every slide renders upside down. The same trick appears again for `--overview-slide-scale`.

- [ ] Wrap each ratio in `abs()`, in a separate later `@supports (transform: scale(abs(-1)))` block that redeclares only the two custom properties. Editing the existing declarations in place would make `abs()` a hard requirement and push Chrome 104 through 132 off the scaled path onto the unscaled fallback.
- [ ] Rebuild `assets/css/presentation.css` with `npm run build:css`, since the compiled stylesheet is committed and shipped.
- [ ] Add CSS contract assertions for both overrides, for the override appearing after the declaration it overrides, and for the override not reintroducing `transform:`.
- [ ] Changelog entry in user terms.
- [ ] Unverifiable here: no Safari is available to this session. The fix rests on the diagnosis that only the sign is wrong, and needs a real Safari check before release.

## 6. Verification

Owner: leader.

- [ ] `bundle exec rake` in full: RuboCop, unit tests, JavaScript, CSS contracts, gem verification, installed-gem example.
- [ ] `bundle exec rake docs` to regenerate `doc/` and `llm.txt` for the new classes, since generated documentation is committed and shipped.
- [ ] `git diff --check`.
- [ ] Report what was verified and what was not. Leave the work ready for review; commit only when asked.
