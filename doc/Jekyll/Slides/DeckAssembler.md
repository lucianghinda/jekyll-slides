# Module Jekyll::Slides::DeckAssembler <a id="module-Jekyll-Slides-DeckAssembler"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/jekyll/slides/deck_assembler.rb |

Finds folder-deck entries across a site's pages and output-collection
documents, assembles each into one Markdown string via `Deck`, and prunes the
slide files it consumed so they never appear in the built site. Runs once per
site, inside the +:site, :post_read+ hook, before Liquid rendering and before
<code>JekyllIntegration.process</code> computes `slides_count`.

## Public Class Methods
### `assemble(site)` <a id="method-c-assemble"></a> <a id="assemble-class_method"></a>
Assembles every folder deck the site's pages and output-collection documents
opt into. Mutates <code>site.pages</code>, each collection's `docs`, and
<code>site.static_files</code> in place to remove consumed slide files.
