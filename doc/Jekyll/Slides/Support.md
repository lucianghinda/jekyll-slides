# Module Jekyll::Slides::Support <a id="module-Jekyll-Slides-Support"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/jekyll/slides/support.rb |

## Public Class Methods
### `escape(value)` <a id="method-c-escape"></a> <a id="escape-class_method"></a>
Not documented.

### `natural_sort_key(name)` <a id="method-c-natural_sort_key"></a> <a id="natural_sort_key-class_method"></a>
A comparable Array key for natural filename ordering: digit runs compare
numerically, text runs compare case-insensitively, and digit runs sort before
text runs. The name itself is appended as a stable tiebreaker so equal-value
keys (e.g. "01-a" and "1-a") still order deterministically.

### `warn(warning, message)` <a id="method-c-warn"></a> <a id="warn-class_method"></a>
Not documented.
