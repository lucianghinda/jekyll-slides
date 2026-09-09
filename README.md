# Jekyll Slides

`jekyll-slides` turns one Markdown page into a polished, accessible 16:9 presentation. It is a plugin that supplies its own presentation layout and assets without replacing the site's theme.

## Install

Add the gem and plugin to the site:

```ruby
# Gemfile
gem "jekyll-slides"
```

```yaml
# _config.yml
plugins:
  - jekyll-slides
```

Keep the site's existing `theme:` setting, if any. The plugin provides the `presentation` layout itself; a site-local layout or asset with the same path takes precedence.

Run `bundle install`, then `bundle exec jekyll serve`. The gem supports Ruby 3.1+ and Jekyll 4.3–4.x. Use Jekyll 4.4 or newer with Ruby 3.4 or newer; Jekyll 4.3 relies on libraries that those Ruby versions no longer bundle.

## Author a deck

Set `layout: presentation` in the page front matter. YAML front matter is the first `---` pair and belongs to the page; every later line containing only `---` separates slides. A separator inside a fenced code block is code, not a slide break. Because exact `---` lines are separators, setext level-two headings are not supported in decks; use `## Heading` instead.

```markdown
---
layout: presentation
title: A short talk
---

<!--
layout: title
background: gradient
-->
# A short talk

---

<!--
layout: content
-->
# The idea

One clear thought per slide.
```

Slide comments are optional. Supported layouts are `title`, `statement`, `content`, `code`, `code-left`, `code-right`, `split-code`, and `code-result`. Without a comment, layout is inferred: the first text slide is a title, code/editor slides become code layouts, editor pairs become split-code, and an editor plus terminal becomes code-result.

Supported backgrounds are `plain`, `gradient`, `grid`, and `spotlight`. Add `class: my-class` in the comment for a custom slide class:

```html
<!--
layout: statement
background: spotlight
class: keynote
-->
```

## Deck folders

A deck can also be a folder of Markdown files, one file per slide, instead of one file with `---` separators:

```
talks/my-talk/
  index.md          # deck front matter, opts in with `slides: true`
  01-title.md
  02-the-idea.md
  03-code.md
  diagram.png        # ordinary static file, untouched
```

The entry file must be named `index.md` and carry the deck's front matter, `layout: presentation`, and `slides: true`:

```yaml
# talks/my-talk/index.md
---
layout: presentation
title: My talk
slides: true
---
```

`slides: true` discovers every other Markdown file that is a direct child of the folder (not recursive), skipping names starting with `_` or `.`, and skipping anything Jekyll itself withholds: a file dropped by the site's `exclude:` setting, or one whose front matter sets `published: false`. Naming a withheld file in an explicit list warns and skips it too, so a deck never publishes content the site holds back. Files are ordered by a natural sort of the filename: digit runs compare numerically and sort before letters, so `01-title.md`, `02-the-idea.md`, `10-outro.md`, then any file with no numeric prefix, sorted alphabetically. Each file holds one slide, or several separated by `---`, exactly as in a single-file deck. Body content in `index.md`, if any, becomes the deck's leading slides.

A slide file can carry its own YAML front matter with `layout`, `background`, and `class`, as an alternative to the `<!-- ... -->` comment:

```markdown
---
layout: statement
background: spotlight
---
# A bold claim
```

Front matter in the file applies to every slide it holds; a slide's own comment overrides it key by key.

Set `slides:` to a list instead of `true` to turn the entry file into a readable running order, in presentation order:

```yaml
---
layout: presentation
title: My talk
slides:
  - 01-title.md
  - 02-the-idea.md
  # - 03-detour.md
  - 04-code.md
---
```

Cutting a slide for a shorter time slot is commenting out one line, not moving a file out of the folder.

`slides:` is what opts a folder in. Opting in absorbs the whole folder: every Markdown file it absorbs is removed from the site's pages, collection documents, and static files, so none of them is ever published on its own. This holds even for a file commented out of an explicit list; the list controls order and inclusion in the deck, not what gets absorbed. Without `slides:`, a folder holding an `index.md` presentation behaves exactly as it does today, and sibling files are left alone. This matters if the site applies `layout: presentation` through a broad `defaults:` rule, since that alone never triggers absorption.

## Editors and terminals

Put a kramdown inline attribute list immediately after a fenced block. Attribute values must be quoted; class and ID tokens such as `.editor` and `#order-total` do not need quotes. `.editor` renders a syntax-highlighted editor window; `.terminal` renders a terminal window.

````markdown
```ruby
class Order
  def total
    items.sum(&:price)
  end
end
```
{: .editor #order-total title="app/models/order.rb" size="lg" focus="2-4" highlight="3" line_numbers="true"}

```text
$ bundle exec ruby -v
ruby 3.4.1
```
{: .terminal #ruby-version title="terminal" size="sm"}
````

Editor/terminal attributes are `title`, `id` (or `#id`), `size` (`sm`, `md`, `lg`), `line_numbers` (`true`/`false`), `focus`, and `highlight`. Ranges accept comma-separated lines and ranges such as `2,4-6,9`; invalid values fall back safely with a Jekyll warning. Terminal prompts beginning with `$ `, `> `, or `❯ ` are styled separately. Source remains server-rendered and copyable.

Long editor and terminal blocks scroll within the slide. Blocks over 20 lines produce an advisory build warning; the amount that fits depends on the layout and font size. Split long examples across slides for print, where scrolling is unavailable.

Liquid runs before slide rendering, just as it does on ordinary Jekyll pages. Wrap examples that contain Liquid syntax in `{% raw %}` and `{% endraw %}`. Because each slide is converted as one Markdown document, the raw block may surround an editor fence without being separated from it.

Code remains selectable and copyable with normal browser controls; version 0.1 does not add a copy button.

## Themes and configuration

Presentation themes are `minimal-light`, `minimal-dark`, `midnight` (the default), and `ruby`. These style the slides without replacing the site's Jekyll theme. Configure defaults under `slides:`:

```yaml
slides:
  theme: midnight
  aspect_ratio: "16:9"
  progress: true
  slide_numbers: true
  overview: true
  fullscreen: true
```

The same keys can be overridden per presentation in front matter (`theme`, `aspect_ratio`, `progress`, `slide_numbers`, `overview`, and `fullscreen`), including Jekyll's scoped `defaults:` for pages and collection documents. The runtime currently supports the fixed `16:9` aspect ratio; invalid values use the safe default. Always quote `"16:9"` in YAML to prevent it from being parsed as a number.

For a light presentation, set `slides: { theme: minimal-light }` in `_config.yml`, or `theme: minimal-light` in the deck's front matter. The [readability example](https://github.com/lucianghinda/jekyll-slides/blob/main/examples/readability.md) demonstrates the light theme with code, terminal output, tables, and prose.

## Typography and readability

The gem bundles Atkinson Hyperlegible Next for text and Atkinson Hyperlegible Mono for code, including variable upright and italic faces. Fonts load from the site's own assets and work offline. The font files retain their SIL Open Font License; source revisions, checksums, and notices are in [assets/fonts](https://github.com/lucianghinda/jekyll-slides/blob/main/assets/fonts/README.md).

On the 1920×1080 slide canvas, body text is 44px, section headings are 72px, and code sizes `sm`, `md`, and `lg` are 32px, 38px, and 42px. These sizes scale with the slide. Filenames and line numbers remain readable, and focused lines use borders and background color while keeping surrounding code fully visible. All four themes check syntax-token contrast against normal, highlighted, and focused code surfaces.

Prefer medium or large code and short examples for projection. Long blocks can scroll, but an audience cannot reveal hidden lines independently; split examples when presenting or printing. Screen contrast tests do not replace checking the actual projector and viewing distance.

## Navigation and accessibility

Use `ArrowLeft`/`ArrowRight`, `PageUp`/`PageDown`, `Home`, and `End` to navigate. `Space` advances, `O` toggles overview, and `F` toggles fullscreen. The current slide is synchronized in the URL hash (`#3` for slide three), so links and browser history work. The controls include accessible labels and focus states; reduced-motion preferences are respected. Print the deck with the browser print dialog (slides are paginated and chrome is hidden). If JavaScript is disabled, all slides remain in document order as complete aspect-ratio frames with readable content.

## Demo and development

In a repository checkout (the demo is intentionally not included in the runtime gem), build the included ten-slide refactoring story:

```sh
cd examples
bundle install
bundle exec jekyll build --source . --destination _site
```

From the gem directory, run `bundle install` and `npm ci`, then `bundle exec rake` to run Ruby tests, JavaScript tests, the Tailwind build and CSS contract tests, gem verification, and the example build. The demo can also be served with `bundle exec jekyll serve --source examples --destination examples/_site`.

Tailwind source is in `src/css`; the committed runtime stylesheet is `assets/css/presentation.css`:

```sh
npm install
npm run build:css
npm run dev:css
npm run test:javascript
npm run test:css
```

Users do not need Node or Tailwind at runtime; they are development tools for this repository.

## Generated documentation

Generate Markdown API documentation and the LLM index from the Ruby source:

```sh
bundle exec rake docs
```

This replaces `doc/` with fresh YARD Markdown, updates the documentation index in
`doc/Jekyll/Slides.md`, and writes `llms.txt` with links relative to the gem root.
The generated files are checked in and shipped with the gem. Internal plans,
temporary files, and Node dependencies are excluded. YARD and `yard-markdown`
are development tools only.

For the individual steps, run `bundle exec rake yard`, then
`ruby bin/generate_llm.rb`. To verify everything, regenerate documentation, and
build the versioned gem and SHA-256 checksum in `pkg/`, run:

```sh
bin/prepare_release
```

Release preparation stops if a check or generation step fails. It does not
commit, tag, push, or publish the gem.

Rendering and toolchain decisions that should not be re-derived casually are recorded in the [architecture decision record](https://github.com/lucianghinda/jekyll-slides/blob/main/docs/architecture-decisions.md).

Maintainers can follow the [release instructions](https://github.com/lucianghinda/jekyll-slides/blob/main/docs/releasing.md) to verify, build, tag, and publish a gem.

## 0.1 limitations and extension

Version 0.1 intentionally supports Markdown/Kramdown, a fixed 16:9 canvas, the curated layouts/themes above, and a small dependency-free browser runtime. It does not provide speaker notes, transitions, nested slide sections, a theme editor, or an authoring UI. JavaScript is enhancement-only; server-side HTML is the source of truth.

The plugin injects its `_layouts`, `_includes`, and `assets` into Jekyll without participating in theme resolution. A site can override the `presentation` layout, any `slides/*` include, or either compiled asset by placing a file with the same path in its own source tree. Copy the stylesheet only when you need a complete CSS fork; otherwise add a custom slide class and site CSS after the gem stylesheet. Keep `plugins: [jekyll-slides]` enabled even when overriding the layout so Markdown rendering and normalized slide settings remain active.

Released under the Apache-2.0 license.
