# Class Jekyll::Slides::SlideFile <a id="class-Jekyll-Slides-SlideFile"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/jekyll/slides/slide_file.rb |

Reads one Markdown file and returns its slide sources. The file's own front
matter (`layout`, `background`, `class`) becomes a default metadata comment
applied to every slide the file contains; a slide's own comment wins key by
key.

## Public Instance Methods
### `initialize(path, warning: = nil, read_options: = {})` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
- **@return** [SlideFile] a new instance of SlideFile

### `slides()` <a id="method-i-slides"></a> <a id="slides-instance_method"></a>
Not documented.
