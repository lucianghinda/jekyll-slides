# Class Jekyll::Slides::Deck <a id="class-Jekyll-Slides-Deck"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/jekyll/slides/deck.rb |

Represents one folder deck: an entry file plus the slide files a directory
holds. Reads slide files from disk and assembles them, with the entry body,
into one Markdown string ready for the existing `PresentationParser` pipeline.
Knows nothing about Jekyll page objects.

## Constants
### `OPTION_KEYS` <a id="constant-OPTION_KEYS"></a> <a id="OPTION_KEYS-constant"></a>
Top-level presentation options an author might mistakenly nest under
<code>slides:</code> instead of setting directly in front matter.

## Public Instance Methods
### `consumed_paths()` <a id="method-i-consumed_paths"></a> <a id="consumed_paths-instance_method"></a>
Every slide file the deck folder absorbs, so none is published on its own:
every discovered direct child, plus any explicitly listed path (which may live
in a subfolder). Order is not meaningful; this is a set for pruning, not the
render order. Identical to `slide_paths` when <code>slides:</code> is `true`.

### `content()` <a id="method-i-content"></a> <a id="content-instance_method"></a>
Not documented.

### `deck?()` <a id="method-i-deck-3F"></a> <a id="deck?-instance_method"></a>
rubocop:enable Metrics/ParameterLists
- **@return** [Boolean]

### `initialize(directory:, entry_path:, entry_body:, slides:, markdown_extensions:, warning: = nil, read_options: = {}, published: = nil)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
rubocop:disable Metrics/ParameterLists -- this exact keyword set is the deck's
public construction contract; the Jekyll integration layer wires it verbatim.
- **@return** [Deck] a new instance of Deck

### `slide_paths()` <a id="method-i-slide_paths"></a> <a id="slide_paths-instance_method"></a>
The ordered slide file paths that make up `content`: the explicit list in list
order when <code>slides:</code> names one, otherwise every discovered file in
natural order.
