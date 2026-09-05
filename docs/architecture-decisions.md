# Architecture decisions

These decisions are part of the rendering contract. Change them only with a regression that demonstrates why the contract should move.

## Plugin ownership

Jekyll Slides is a plugin, not a site theme. It injects its `presentation` layout, slide includes, and compiled assets only when the site does not provide an override. A site keeps its existing `theme` setting.

## Rendering phase

Presentation pages use `Jekyll::Slides::Renderer`. Liquid evaluates the author's Markdown first; the renderer then replaces Jekyll's ordinary Markdown conversion with slide rendering. Generated component HTML therefore never passes through Liquid or the site's Markdown converter.

## Markdown model

Each slide is parsed once into a kramdown element tree. Layout inference and component rendering share that tree, and editor and terminal code blocks are transformed before a single HTML conversion. Per-slide heading and footnote prefixes prevent duplicate IDs; converter-generated tails such as footnotes remain after the final authored fragment. Do not restore line-oriented fence/IAL scanners or split prose into independent converter calls: cross-heading references, footnotes, abbreviations, and generated heading IDs depend on the whole-slide document.

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
