# Slide readability implementation plan

> **For agentic workers:** Use superpowers-ruby:subagent-driven-development or superpowers-ruby:executing-plans to implement this plan task by task.

**Goal:** Apply the approved Atkinson typography and contrast proposal while preserving technical code windows, slide layouts, and all four themes, including minimal-light.

**Architecture:** Keep presentation styling in the existing CSS components and compiled asset. Ship fonts and their licenses through the existing plugin asset installer; retain relative asset URLs and site overrides. Theme selection continues to use `slides.theme` and page front matter.

**Tech stack:** Ruby/Jekyll, kramdown/Rouge, Tailwind CSS, existing browser runtime, Minitest, Chromium for visual checks. No new runtime or development dependencies.

## 1. Offline fonts

Owner: font packaging agent. Files: `assets/fonts/`, `src/css/components/_fonts.css`, `test/package_test.rb`, `test/example_presentation_test.rb`.

- [x] Add failing archive and installed-site checks for normal/italic Next and Mono fonts and OFL notices.
- [x] Obtain official variable WOFF2 files, recording origin, version and checksums.
- [x] Register each face with its actual family name, `font-weight: 200 800`, correct style, `font-display: swap`, and a relative `../fonts/` URL.
- [x] Run package and installed-example tests.

## 2. Typography, layout and theme contrast

Owner: leader. Files: `src/css/app.css`, `_tokens.css`, `_base.css`, `_slides.css`, `_code.css`, `test/presentation_css_test.rb`, compiled CSS.

- [x] Add failing regression checks for font registration, full-opacity contextual code, and every syntax token's contrast against normal/highlight/focus surfaces in all themes. Assert a 4.5:1 floor, and explicitly check the light theme has a light surface with dark text.
- [x] Import font declarations and apply Next/Mono stacks. Use 44px body, 72px headings, 32/38/42px component code, 28px filenames, 24px language labels, and full-opacity line numbers. Use body weight 400, heading 600, code 450, captions 500. Keep programming ligatures off.
- [x] Relax body tracking to zero and heading tracking to -.012em; use line heights 1.4 and 1.12. Restore near-body-sized inline code and body-sized tables.
- [x] Apply the reviewed theme colors, remove whole-line fading, retain the focus border and tint, and make overflow scrollbars discoverable.
- [x] Give full-width code the available canvas width; widen code-result headings to 24ch and reduce its gap to 24px so the existing examples still fit.
- [x] Rebuild using `npm run build:css` and run CSS contracts.

## 3. Light-theme documentation and verification

Files: `README.md`, `CHANGELOG.md`, `docs/architecture-decisions.md`, `examples/` if a dedicated showcase helps.

- [x] Document `slides: { theme: minimal-light }`, page overrides, offline fonts/licenses, and the new type scale. Preserve the site's ordinary Jekyll theme.
- [x] Build real examples with a baseurl; check all four palettes, font loads, ten example slides, overview at 1280/1600/1920 widths, code scrolling, narrow document flow, print, tables, quotes, and footnotes.
- [x] Inspect screenshots and persist visual verdicts under `.omx/state/` before further visual iterations.
- [x] Run `bundle exec rake`, `git diff --check`, and a focused independent review. Report remaining real-projector and browser-matrix limits.

The user approved implementation in this session. No additional planning approval is required. Leave the completed changes ready for review; commit only when requested.
