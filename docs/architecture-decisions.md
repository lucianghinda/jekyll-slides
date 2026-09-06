# Architecture decisions

These decisions are part of the rendering contract. Change them only with a regression that demonstrates why the contract should move.

## Plugin ownership

Jekyll Slides is a plugin, not a site theme. It injects its `presentation` layout, slide includes, and compiled assets only when the site does not provide an override. A site keeps its existing `theme` setting.

## Rendering phase

Presentation pages use `Jekyll::Slides::Renderer`. Liquid evaluates the author's Markdown first; the renderer then replaces Jekyll's ordinary Markdown conversion with slide rendering. Generated component HTML therefore never passes through Liquid or the site's Markdown converter.

## Markdown model

Each slide is parsed once into a kramdown element tree. Layout inference and component rendering share that tree, and editor and terminal code blocks are transformed before a single HTML conversion. Per-slide heading and footnote prefixes prevent duplicate IDs; converter-generated tails such as footnotes remain after the final authored fragment. Do not restore line-oriented fence/IAL scanners or split prose into independent converter calls: cross-heading references, footnotes, abbreviations, and generated heading IDs depend on the whole-slide document.

## Deck assembly

Folder-deck assembly runs in the `:site, :post_read` hook, before `JekyllIntegration.process` and before Liquid ever runs. `DeckAssembler` and `Deck` emit plain Markdown, joined by `\n\n---\n\n`, exactly like an author's own `---`-separated file. The rendering contract in "Rendering phase" and "Markdown model" above is untouched: `Renderer`, `PresentationParser`, and everything downstream still see one Markdown string and never learn it was assembled from several files.

Absorption only happens when the entry front matter sets `slides:`. The README documents `defaults:` rules that apply `layout: presentation` to a whole subtree; automatic folder detection would let such a rule turn any folder holding an `index.md` into a deck and silently swallow its sibling pages. Making absorption opt-in keeps that decision with the author.

`SlideFile` reads slide files from disk rather than through Jekyll page objects. A Markdown file with no front matter is not a `Jekyll::Page`; front matter is what makes Jekyll treat a file as a page at all, so a front-matter-less slide file is read as a `Jekyll::StaticFile` instead. Reading straight from disk handles both cases uniformly and returns the author's real front matter, unaffected by `defaults:` merging. Because a slide file can surface as either a page/document or a static file, `DeckAssembler` prunes all three collections it might be sitting in: `site.pages`, every collection's `docs`, and `site.static_files`.

Discovery filters its results through the set of source paths Jekyll actually read, snapshotted before any pruning. Reading the folder from disk is what makes a front-matter-less slide file work, but it also bypasses the filtering Jekyll already applied, so an excluded file or one marked `published: false` would otherwise be absorbed and published inside the deck. An explicitly listed path is filtered the same way and warns, because withholding content is the safe direction to resolve a contradiction between an author's list and the site's own settings.

Pruning runs for every valid folder deck, whether or not the running order selected anything. An explicit list controls what the deck renders, not what the folder absorbs, so an empty or partial list must still keep the omitted files out of the built site.

`Renderer#convert` recomputes `slides_count` from the post-Liquid source and writes it to two places: `document.data["slides_count"]` and `payload["page"]["slides_count"]`. Both writes are required, for different reasons per document type. A `Document` (an output-collection page) is exposed to its layout through a live `DocumentDrop` that reads `document.data` on every access, so writing `document.data` alone is enough for it. A `Page` is exposed to its layout through a plain `Hash` snapshot that `Jekyll::Renderer#assign_pages!` builds and stores in `payload["page"]` before `convert` runs; that snapshot does not see later writes to `document.data`, so a `Page`'s layout would keep rendering the stale, pre-Liquid slide count unless `payload["page"]` is updated too. Do not drop either write.

## Canvas scaling

The 1920×1080 canvas and overview thumbnails scale from CSS container units. JavaScript owns navigation and accessibility state, not geometry.

Overview thumbnails use inline-size containment and width-based scaling. Their grid needs `grid-auto-rows: max-content`: automatic rows can still compress below the thumbnail height in a definite-height deck, even with inline-size containment. Check decks with enough slides to overflow vertically, including 10 and 12 slides at 1600×900.

## Fonts

The runtime ships Atkinson Hyperlegible Next and Atkinson Hyperlegible Mono as unmodified, versioned variable WOFF2 fonts, including upright and italic faces. Relative CSS URLs preserve baseurl hosting and offline use. Each font family retains its OFL notice; provenance and checksums are recorded under `assets/fonts/`. System fonts remain fallbacks while bundled faces load.

Code focus uses a border and background without reducing surrounding text opacity. Syntax and muted text colors must retain at least 4.5:1 contrast on normal, highlighted, and focused code surfaces in every palette, including minimal-light. Canvas font sizes are scaled by the presentation viewport, so their source pixel size does not establish audience readability by itself.

## CSS toolchain

The compiled stylesheet is committed, so gem users do not need Node. Repository development currently uses the pinned Tailwind npm CLI; changing to `tailwindcss-ruby` is intentionally deferred until adding that development dependency is approved.

## Runtime dependencies

Jekyll, kramdown, `kramdown-parser-gfm`, and Rouge are direct gem dependencies because production code requires their APIs. Development-only CSS tooling and optional font binaries are separate decisions and must not leak into the runtime dependency set.
