# Module Jekyll::Slides::FrontMatter <a id="module-Jekyll-Slides-FrontMatter"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/jekyll/slides/front_matter.rb |

Splits a leading YAML front matter block off a Markdown source string.

## Public Class Methods
### `parse(text)` <a id="method-c-parse"></a> <a id="parse-class_method"></a>
Not documented.

### `split(source)` <a id="method-c-split"></a> <a id="split-class_method"></a>
Returns [values, body]. `values` is a Hash for a well-formed leading
<code>---</code> block; otherwise `values` is {} and `body` is `source`
unchanged.
