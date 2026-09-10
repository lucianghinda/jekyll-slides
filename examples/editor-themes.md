---
layout: presentation
title: Editor themes
theme: midnight
permalink: /editor-themes/
---

<!--
layout: title
background: plain
-->
# A light window in a dark deck

## `theme="macos-light"` repaints one window and nothing else

---

<!--
layout: code
-->
# The deck stays dark

```ruby
class Invoice
  def total = items.sum(&:price)
end
```
{: .editor title="app/models/invoice.rb" theme="macos-light" line_numbers="true"}

---

<!--
layout: split-code
-->
## Deck theme

```ruby
def total(items)
  items.sum(&:price)
end
```
{: .editor title="inherited.rb" size="sm" line_numbers="true"}

## macOS light

```ruby
def total(items)
  items.sum(&:price)
end
```
{: .editor title="app/models/concerns/invoice_totals_by_currency.rb" size="sm" theme="macos-light" line_numbers="true"}

---

<!--
layout: code-result
-->
# Run it

```ruby
# A long line, to check that the window scrolls instead of overflowing the slide
invoice = Invoice.new(items: [Item.new(price: 10), Item.new(price: 32)])
invoice.total
```
{: .editor title="script.rb" size="sm" theme="macos-light" highlight="2" focus="3" line_numbers="true"}

```console
$ ruby script.rb
42
```
{: .terminal title="zsh" size="sm" theme="macos-light"}

---

<!--
layout: code
-->
# Large, with a long filename

```ruby
Invoice.where(status: :open).sum(&:total)
```
{: .editor title="app/services/billing/monthly_statement_generator.rb" size="lg" theme="macos-light" highlight="1" line_numbers="true"}
