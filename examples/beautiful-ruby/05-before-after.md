---
layout: split-code
background: gradient
---
# Before → after

```ruby
line_items.sum { _1.subtotal }
```
{: .editor #before title="before: invoice.rb" size="md" line_numbers="false"}

```ruby
line_items.sum(&:subtotal)
```
{: .editor #after title="after: invoice.rb" size="md" highlight="1" line_numbers="true"}
