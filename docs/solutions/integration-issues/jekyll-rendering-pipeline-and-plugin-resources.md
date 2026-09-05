---
title: Preserving Jekyll's Rendering Pipeline While Injecting Plugin Resources
date: 2026-09-04
category: integration-issues
problem_type: integration_issue
component: jekyll_slides_rendering_pipeline
severity: high
tags:
  - jekyll
  - liquid
  - kramdown
  - plugin-integration
  - rendering-lifecycle
  - resource-injection
---

# Preserving Jekyll's rendering pipeline while injecting plugin resources

## Symptoms

- Liquid examples such as `{{ user.name }}` disappeared from editor components.
- `kramdown.parse_block_html: true` reparsed generated component HTML and corrupted its structure.
- Converting prose fragments separately broke reference links, footnotes, abbreviations, and unique IDs.
- Requiring `theme: jekyll-slides` displaced a site's existing theme and hid the intended plugin contract.

The original implementation had diverged from an empirically tested plan without recording why (auto memory [claude]). The failures were consequences of crossing Jekyll's lifecycle boundaries, not isolated escaping bugs.

## Root cause

A `:pre_render` hook replaced the page's Markdown with final HTML. Jekyll then ran Liquid and the configured Markdown converter over that generated HTML. A line-oriented fence/IAL scanner also split each slide into separately converted fragments, discarding whole-document Markdown semantics.

Plugin layouts and assets were packaged like a theme, so installation depended on theme resolution instead of coexisting with the site's theme.

## Resolution

1. A site `:post_read` hook installs plugin resources and assigns a presentation-specific `Jekyll::Renderer`; it never replaces `document.content`.
2. Liquid evaluates the source first. `Renderer#convert` then replaces Jekyll's ordinary Markdown conversion with slide rendering, so generated HTML is converted exactly once.
3. Each slide becomes one kramdown element tree. Layout inference and component substitution share that parse. Heading and footnote IDs receive per-slide prefixes, and converter tails remain after the final authored fragment.
4. The plugin provides its layout, includes, and compiled assets without setting the site's theme. Site layouts, includes, static files, pages, and generated output at the same destination retain precedence.
5. CSS owns canvas geometry; JavaScript owns navigation and accessibility state. Fixed-canvas scaling is feature-gated so unsupported browsers keep readable document flow.

## Regression strategy

- Use real Jekyll builds to prove literal Liquid inside `{% raw %}` editor fences and intact output with `parse_block_html` both enabled and disabled.
- Exercise reference definitions, abbreviations, footnotes after later headings, repeated footnote names across slides, converter-tail order, and non-GFM parser options.
- Build collection presentations and assert that site-generated asset pages are not overwritten.
- Verify numeric slide hashes independently from ordinary internal anchors.
- Check computed geometry in a real browser; keep CSS source assertions limited to narrow ownership and fallback contracts.
- Build and install the gem in isolation so missing runtime files or undeclared dependencies cannot be masked by the checkout.

## Deliberate deferrals

The committed stylesheet still uses the pinned npm Tailwind CLI for repository development, and JavaScript unit tests still use the dependency-free DOM fixture. Moving to `tailwindcss-ruby` or jsdom would add development dependencies and requires explicit approval. Real-browser checks cover the geometry that the unit fixture cannot model. Self-hosted fonts likewise remain deferred until their licensed binary assets and distribution terms are decided.

## Related material

- [Architecture decisions](../../architecture-decisions.md)
- Renderer lifecycle regressions: `test/jekyll_integration_test.rb`
- Whole-slide Markdown regressions: `test/slide_renderer_test.rb`
- CSS ownership and fallback regressions: `test/presentation_css_test.rb`
- Runtime navigation regressions: `test/javascript/presentation_test.js`
