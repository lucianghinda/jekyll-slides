---
layout: presentation
title: Beautiful Ruby
description: A small refactoring with a large payoff
permalink: /beautiful-ruby/
---

<!--
layout: title
background: gradient
-->
# Beautiful Ruby

## A refactoring story in ten small moves

Ruby reads best when the design is visible at a glance.

---

<!--
layout: statement
background: spotlight
-->
# Make the happy path obvious

The best refactor is the one that lets the next reader think about the domain instead of the plumbing.

---

<!--
layout: code
background: grid
-->
```ruby
class Invoice
  def total
    line_items.sum { |item| item.price * item.quantity }
  end
end
```
{: .editor #full-result title="app/models/invoice.rb" size="lg" line_numbers="true"}

---

<!--
layout: code-right
background: plain
-->
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

---

<!--
layout: split-code
background: gradient
-->
# Before → after

```ruby
line_items.sum { _1.subtotal }
```
{: .editor #before title="before: invoice.rb" size="md" line_numbers="false"}

```ruby
line_items.sum(&:subtotal)
```
{: .editor #after title="after: invoice.rb" size="md" highlight="1" line_numbers="true"}

---

<!--
layout: code-result
background: grid
-->
# A refactor should earn trust

The test still tells the same story, while the production code now has a name for the rule.

```ruby
expect(invoice.total).to eq(42)
```
{: .editor #spec title="spec/models/invoice_spec.rb" size="md" line_numbers="true"}

```text
$ bundle exec rspec spec/models/invoice_spec.rb
.

Finished in 0.08 seconds
1 example, 0 failures
```
{: .terminal #passing-test title="test run" size="sm"}

---

<!--
layout: code
background: plain
-->
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

---

<!--
layout: code
background: spotlight
-->
# Highlight the one meaningful change

```ruby
class LineItem
  def subtotal
    price * quantity
  end
end
```
{: .editor #highlighted-rule title="app/models/line_item.rb" size="md" highlight="2-3" line_numbers="true"}

---

<!--
layout: code
background: grid
-->
```text
❯ bundle exec rubocop
Inspecting 12 files
12 files inspected, no offenses detected

❯ bundle exec rspec
42 examples, 0 failures
```
{: .terminal #clean-checks title="CI locally" size="lg"}

---

<!--
layout: content
background: plain
-->
# Three habits to keep

- Give domain rules a name.
- Keep the public method easy to scan.
- Let tests describe the behavior, not the implementation.

Small, legible changes compound into beautiful Ruby.
