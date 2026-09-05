# Module Jekyll::Slides <a id="module-Jekyll-Slides"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/jekyll/slides.rb, lib/jekyll/slides/assets.rb, lib/jekyll/slides/layout.rb, lib/jekyll/slides/support.rb, lib/jekyll/slides/version.rb, lib/jekyll/slides/renderer.rb, lib/jekyll/slides/presentation.rb, lib/jekyll/slides/range_parser.rb, lib/jekyll/slides/rouge_renderer.rb, lib/jekyll/slides/slide_metadata.rb, lib/jekyll/slides/slide_renderer.rb, lib/jekyll/slides/component_renderer.rb, lib/jekyll/slides/jekyll_integration.rb, lib/jekyll/slides/presentation_parser.rb |

Markdown presentations for Jekyll, with editor and terminal components.

Add <code>jekyll-slides</code> to the site's plugins and choose the
`presentation` layout on a Markdown page. Separate slides with
<code>---</code> outside fenced code blocks. The plugin supplies layouts,
includes, styles, scripts, and offline fonts while preserving the site's theme
and local overrides.

Configure defaults under <code>slides:</code> in _config.yml, or use front
matter on individual decks. Themes are `midnight`, <code>minimal-light</code>,
<code>minimal-dark</code>, and `ruby`. The supported aspect ratio is 16:9;
quote this value in YAML.

Jekyll runs Liquid before rendering each slide as one Markdown document.
Jekyll::Slides::Presentation also renders slide HTML directly when Jekyll
integration is not needed; it does not evaluate Liquid or wrap the
presentation layout.

## Constants
### `LAYOUT_NAME` <a id="constant-LAYOUT_NAME"></a> <a id="LAYOUT_NAME-constant"></a>
Not documented.

### `ROOT` <a id="constant-ROOT"></a> <a id="ROOT-constant"></a>
Not documented.

### `VERSION` <a id="constant-VERSION"></a> <a id="VERSION-constant"></a>
Not documented.

# Documentation

- [Slides/Assets/SiteAssetFile.md](Slides/Assets/SiteAssetFile.md)
- [Slides/Assets.md](Slides/Assets.md)
- [Slides/ComponentRenderer/RenderedDocument.md](Slides/ComponentRenderer/RenderedDocument.md)
- [Slides/ComponentRenderer.md](Slides/ComponentRenderer.md)
- [Slides/JekyllIntegration.md](Slides/JekyllIntegration.md)
- [Slides/Layout.md](Slides/Layout.md)
- [Slides/Presentation.md](Slides/Presentation.md)
- [Slides/PresentationParser.md](Slides/PresentationParser.md)
- [Slides/RangeParser.md](Slides/RangeParser.md)
- [Slides/Renderer.md](Slides/Renderer.md)
- [Slides/RougeRenderer.md](Slides/RougeRenderer.md)
- [Slides/SlideMetadata.md](Slides/SlideMetadata.md)
- [Slides/SlideRenderer.md](Slides/SlideRenderer.md)
- [Slides/Support.md](Slides/Support.md)
