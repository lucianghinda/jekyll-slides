# Class Jekyll::Slides::Presentation <a id="class-Jekyll-Slides-Presentation"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/jekyll/slides/presentation.rb |

Renders a Markdown deck into slide sections without the page layout.

## Public Instance Methods
### `initialize(markdown, warning: = nil, options: = {})` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
- **@param** `markdown` [String] Markdown without page YAML front matter
- **@param** `warning` [#call, nil] receives advisory rendering warnings
- **@param** `options` [Hash] kramdown options
- **@return** [Presentation] a new instance of Presentation

### `render(markdown = @markdown)` <a id="method-i-render"></a> <a id="render-instance_method"></a>
- **@param** `markdown` [String] optional replacement for the initial Markdown
- **@return** [String] rendered slide section HTML
