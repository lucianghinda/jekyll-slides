---
layout: code
background: grid
---
```ruby
class Invoice
  def total
    line_items.sum { |item| item.price * item.quantity }
  end
end
```
{: .editor #full-result title="app/models/invoice.rb" size="lg" line_numbers="true"}
