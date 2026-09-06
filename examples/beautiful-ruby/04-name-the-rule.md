---
layout: code-right
background: plain
---
# Name the rule once

The block is correct, but the calculation is hiding in the loop. Pull the concept into a small value object.

```ruby
class LineItem
  def subtotal
    price * quantity
  end
end
```
{: .editor #line-item title="app/models/line_item.rb" size="md" focus="2-4" line_numbers="true"}
