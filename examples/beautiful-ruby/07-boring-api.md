---
layout: code
background: plain
---
# Keep the public API boring

Focused lines make the boundary easy to discuss during review.

```ruby
class Invoice
  def total
    line_items.sum(&:subtotal)
  end
end
```
{: .editor #focused-api title="app/models/invoice.rb" size="md" focus="2-4" line_numbers="true"}
