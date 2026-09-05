# Changelog

All notable changes to Jekyll Slides are documented here.

## Unreleased

- Add `bin/prepare_release` to verify the gem, regenerate Markdown API documentation and `llm.txt`, and build a versioned package with a SHA-256 checksum.
- Ship generated documentation while keeping YARD and release tools development-only.

## 0.1.0 — 2026-09-05

Initial release.

- Turn Markdown pages and collection documents into 16:9 presentations with eight layouts and four themes, including minimal-light.
- Provide presentation layouts, includes, and assets without replacing the site's Jekyll theme or overriding site-local files.
- Render Liquid before parsing each slide as one Markdown document, preserving reference links, footnotes, and generated IDs.
- Render syntax-highlighted editor and terminal windows with captions, line numbers, highlighted lines, and focused lines.
- Bundle Atkinson Hyperlegible Next and Mono, including real italics, for offline text and code rendering.
- Keep surrounding code fully visible and maintain syntax contrast across all themes and selected-line backgrounds.
- Support keyboard navigation, URL hashes, overview thumbnails, progress, slide numbers, fullscreen, and reduced motion.
- Scale slides and overview thumbnails with CSS, provide document flow without JavaScript, and paginate printed decks.
- Honor global and scoped front matter defaults on pages and collection documents.
- Make long code blocks scrollable and warn for blocks over 20 lines; printed examples should be split across slides.
- Include technical and light-theme example decks in the source repository.
- Support Ruby 3.1+ and Jekyll 4.3–4.x without Node or Tailwind at runtime; Ruby 3.4+ requires Jekyll 4.4+.
